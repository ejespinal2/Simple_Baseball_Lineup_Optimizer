library(tidyverse)

# ── Input File ────────────────────────────────────────────────────────────────
# Replace "USER_BATTING_STATS.csv" with your file name.
# Required columns: Player(as Last,First), AB, BB, HBP, SF, SH, H, X2B, X3B, HR
BATTING_DATA <- read.csv("USER_BATTING_STATS.csv")

# ── Plate-Appearance Percentages ───────────────────────────────────────────────
# Derives the per-PA rates the simulator needs directly from the raw counting stats.
BATTING_DATA <- BATTING_DATA %>%
  mutate(
    X1B    = H - X2B - X3B - HR,
    PA     = AB + BB + HBP + SF + SH,
    per_1B = X1B / PA,
    per_2B = X2B / PA,
    per_3B = X3B / PA,
    per_HR = HR  / PA,
    per_FP = (BB + HBP) / PA   # free pass (walk or HBP)
  )

# ── Simulators ────────────────────────────────────────────────────────────────

# Simulates a single plate appearance.
# Returns a one-row data frame with base-state, outs, outcome, and runs scored.
# Simplifying assumptions:
#   - No stolen bases or advancement on outs (SF/SH)
#   - Runner scores from 2nd on a single ~58% of the time
#   - Runner goes 1st-to-3rd on a single ~28% of the time
#   - Runner scores from 1st on a double ~42% of the time
#   - Runner on 2nd always scores on a double
PA_Outcome_Simulator <- function(BaseRunners = rep(0, 3),
                                  per_FP, per_1B, per_2B, per_3B, per_HR,
                                  Outs = 0) {
  PA <- runif(1)

  if (PA > per_FP + per_1B + per_2B + per_3B + per_HR) {
    # ── Out ──────────────────────────────────────────────────────────────────
    Outcome <- "Out"
    Outs    <- Outs + 1
    Runs    <- 0

  } else if (PA <= per_FP) {
    # ── Walk / HBP ───────────────────────────────────────────────────────────
    Outcome <- "Walk"
    if (sum(BaseRunners) == 3) {
      Runs <- 1                                    # bases loaded: run scores
    } else {
      BaseRunners[which(BaseRunners == 0)[1]] <- 1 # fill lowest empty base
      Runs <- 0
    }

  } else if (PA <= per_FP + per_1B) {
    # ── Single ───────────────────────────────────────────────────────────────
    Outcome <- "Single"
    if (BaseRunners[2] == 1) {
      if (runif(1) <= 0.58) {
        # Runner on 2nd scores
        Runs           <- BaseRunners[3] + BaseRunners[2]
        BaseRunners[3] <- BaseRunners[1]
        BaseRunners[2] <- 0
        BaseRunners[1] <- 1
      } else {
        # Runner on 2nd holds at 3rd
        Runs           <- BaseRunners[3]
        BaseRunners[3] <- BaseRunners[2]
        BaseRunners[2] <- BaseRunners[1]
        BaseRunners[1] <- 1
      }
    } else {
      Runs <- BaseRunners[3]
      if (runif(1) <= 0.28) {
        # Runner on 1st goes 1st-to-3rd
        BaseRunners[3] <- BaseRunners[1]
        BaseRunners[1] <- 1
      } else {
        BaseRunners[2] <- BaseRunners[1]
        BaseRunners[1] <- 1
      }
    }

  } else if (PA <= per_FP + per_1B + per_2B) {
    # ── Double ───────────────────────────────────────────────────────────────
    Outcome <- "Double"
    if (runif(1) <= 0.42) {
      # Runner on 1st scores
      Runs        <- sum(BaseRunners)
      BaseRunners <- c(0, 1, 0)
    } else {
      # Runner on 2nd (and 3rd) scores; runner on 1st holds at 2nd
      Runs        <- BaseRunners[2] + BaseRunners[3]
      BaseRunners <- if (BaseRunners[1] == 1) c(0, 1, 1) else c(0, 1, 0)
    }

  } else if (PA <= per_FP + per_1B + per_2B + per_HR) {
    # ── Home Run ─────────────────────────────────────────────────────────────
    Outcome     <- "Home run"
    Runs        <- sum(BaseRunners) + 1
    BaseRunners <- c(0, 0, 0)

  } else {
    # ── Triple ───────────────────────────────────────────────────────────────
    Outcome     <- "Triple"
    Runs        <- sum(BaseRunners)
    BaseRunners <- c(0, 0, 1)
  }

  return(data.frame(
    First       = BaseRunners[1],
    Second      = BaseRunners[2],
    Third       = BaseRunners[3],
    Outs        = Outs,
    Outcome     = Outcome,
    Runs_Scored = Runs,
    Hitter      = NA
  ))
}

# Simulates one half-inning.
# Cycles through the 9-man lineup from Last_Hitter until 3 outs are recorded.
# Returns c(total runs scored, index of next batter due up).
Innings_Runs_Simulator <- function(Lineup, Last_Hitter) {
  Innings_Result <- data.frame(
    First = 0, Second = 0, Third = 0,
    Outs = 0, Outcome = "", Runs_Scored = 0,
    Hitter = Last_Hitter
  )

  Outs          <- 0
  Hitter_Due_Up <- Last_Hitter %% 9 + 1
  Total_Runs    <- 0

  while (Outs < 3) {
    Current   <- tail(Innings_Result, 1)
    AB_Result <- PA_Outcome_Simulator(
      BaseRunners = c(Current$First, Current$Second, Current$Third),
      per_FP = Lineup[Hitter_Due_Up, ]$per_FP,
      per_1B = Lineup[Hitter_Due_Up, ]$per_1B,
      per_2B = Lineup[Hitter_Due_Up, ]$per_2B,
      per_3B = Lineup[Hitter_Due_Up, ]$per_3B,
      per_HR = Lineup[Hitter_Due_Up, ]$per_HR,
      Outs   = Outs
    )
    Innings_Result <- rbind(Innings_Result, AB_Result)
    Hitter_Due_Up  <- (Hitter_Due_Up %% 9) + 1
    Outs           <- AB_Result$Outs
    Total_Runs     <- Total_Runs + AB_Result$Runs_Scored
  }

  return(c(Total_Runs, Hitter_Due_Up))
}

# Simulates a 9-inning game. Returns total runs scored.
Game_Runs_Simulator <- function(Lineup) {
  Last_Hitter <- 0
  Total_Runs  <- 0
  for (inning in 1:9) {
    result      <- Innings_Runs_Simulator(Lineup, Last_Hitter)
    Last_Hitter <- result[2]
    Total_Runs  <- Total_Runs + result[1]
  }
  return(Total_Runs)
}

# Returns a numeric vector of runs scored across No_Games simulated games.
Simulate_Runs_Vector <- function(Lineup, No_Games) {
  runs <- numeric(No_Games)
  for (i in 1:No_Games) {
    runs[i] <- Game_Runs_Simulator(Lineup)
  }
  runs
}

# ── Lineup Setup ──────────────────────────────────────────────────────────────
# Replace player names with the exact strings from the "Player" column of your
# CSV. Order = batting order (slot 1 through 9).

Lineup1 <- tibble(
  Player = c(
    "Last, First",   # Slot 1
    "Last, First",   # Slot 2
    "Last, First",   # Slot 3
    "Last, First",   # Slot 4
    "Last, First",   # Slot 5
    "Last, First",   # Slot 6
    "Last, First",   # Slot 7
    "Last, First",   # Slot 8
    "Last, First"    # Slot 9
  )
) %>% left_join(BATTING_DATA, by = "Player")

Lineup2 <- tibble(
  Player = c(
    "Last, First",   # Slot 1
    "Last, First",   # Slot 2
    "Last, First",   # Slot 3
    "Last, First",   # Slot 4
    "Last, First",   # Slot 5
    "Last, First",   # Slot 6
    "Last, First",   # Slot 7
    "Last, First",   # Slot 8
    "Last, First"    # Slot 9
  )
) %>% left_join(BATTING_DATA, by = "Player")

# ── Simulation Settings ───────────────────────────────────────────────────────
NO_GAMES    <- 10000   # number of games to simulate per lineup
P_THRESHOLD <- 0.05    # significance level for the t-test

# ── Run Simulations ───────────────────────────────────────────────────────────
set.seed(42)   # set seed for reproducibility
runs1 <- Simulate_Runs_Vector(Lineup1, NO_GAMES)
runs2 <- Simulate_Runs_Vector(Lineup2, NO_GAMES)

cat(sprintf("Lineup 1 — mean runs/game: %.4f\n", mean(runs1)))
cat(sprintf("Lineup 2 — mean runs/game: %.4f\n", mean(runs2)))

# ── P-Value Test ──────────────────────────────────────────────────────────────
# Two-sample t-test: p < P_THRESHOLD indicates a statistically significant
# difference in run-scoring between the two lineups.
result <- t.test(runs1, runs2, var.equal = TRUE)
print(result)

if (result$p.value < P_THRESHOLD) {
  cat(sprintf("\nStatistically significant difference (p = %.6f < %.2f).\n",
              result$p.value, P_THRESHOLD))
  cat(sprintf("Lineup %d scores more runs on average.\n",
              ifelse(mean(runs1) > mean(runs2), 1, 2)))
} else {
  cat(sprintf("\nNo statistically significant difference (p = %.6f >= %.2f).\n",
              result$p.value, P_THRESHOLD))
}
