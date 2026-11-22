data {
  int<lower=1> n;
  int<lower=1> k;
  int<lower=1> n_dates;
  int<lower=0> n_animals;
  int<lower=0> n_spreads;
  int<lower=0> n_blocks;
  array[n] int<lower=1, upper=n_dates> date_id;
  array[n] int<lower=1, upper=n_animals + 1> animal_id;
  array[n_animals] int<lower=1, upper=n_spreads> animal_spread_id;
  array[n] int<lower=0, upper=n_blocks> block_id;
  vector[n] y;
  matrix[n, k] x;
  vector<lower=0>[k] coefficient_prior_sd;
  vector<lower=0>[k] coefficient_animal_var;
  vector[n] animal_weight;
}
parameters {
  vector[k] beta;
  real<lower=0> residual_sd;
  real<lower=0> date_sd;
  vector<lower=0>[n_spreads] persistent_sd;
  vector<lower=0>[n_blocks > 0] temporary_sd;
  vector[n_dates] date_raw;
  vector[n_animals] animal_raw;
  vector[n_blocks] block_raw;
}
model {
  vector[n] mean_timing = x * beta + date_sd * date_raw[date_id];
  if (sum(coefficient_animal_var) > 0) {
    beta ~ normal(0, sqrt(square(coefficient_prior_sd)
                          + square(persistent_sd[1]) * coefficient_animal_var));
  } else {
    beta ~ normal(0, coefficient_prior_sd);
  }
  residual_sd ~ normal(0, 60);
  date_sd ~ normal(0, 40);
  persistent_sd ~ normal(0, 30);
  temporary_sd ~ normal(0, 30);
  date_raw ~ std_normal();
  animal_raw ~ std_normal();
  block_raw ~ std_normal();
  if (n_animals > 0) {
    vector[n_animals + 1] animal_effect =
      append_row(0.0, persistent_sd[animal_spread_id] .* animal_raw);
    mean_timing += animal_weight .* animal_effect[animal_id];
  }
  if (n_blocks > 0) {
    mean_timing += temporary_sd[1] * block_raw[block_id];
  }
  y ~ normal(mean_timing, residual_sd);
}
