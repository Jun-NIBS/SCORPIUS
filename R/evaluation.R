#' @title Evaluate the inferred timeline
#'
#' @description \code{evaluate_trajectory} calculates the \emph{consistency} of
#' the predicted time points of samples versus the known progression stages.
#'
#' @usage
#' evaluate_trajectory(time, progression)
#'
#' @param time A numeric vector containing the inferred time points of each sample along a trajectory.
#' @param progression A factor or a numeric vector which represents the progression stages of each sample.
#'
#' @return The consistency value for the predicted timeline.
#'
#' @importFrom stats runif
#'
#' @export
#'
#' @examples
#' ## Generate a dataset
#' dataset <- generate_dataset(type="s", num_genes=500, num_samples=1000, num_groups=4)
#' space <- reduce_dimensionality(dataset$expression, correlation_distance, ndim=2)
#' traj <- infer_trajectory(space)
#'
#' ## Evaluate the trajectory timeline
#' evaluate_trajectory(traj$time, dataset$sample_info$group_name)
evaluate_trajectory <- function(time, progression) {
  # remove any irrelevant parameters from time
  attributes(time) <- attributes(time)[intersect(names(attributes(time)), "names")]

  # input checks
  check_numeric_vector(time, "time", finite = TRUE)
  check_numeric_vector(progression, "progression", finite = TRUE, factor = TRUE)
  if (length(time) != length(progression)) {
    stop(sQuote("time"), " and ", sQuote("progression"), " must have equal lengths.")
  }

  # if progression is a factor, convert it to a numeric
  if (is.factor(progression)) {
    progression <- as.numeric(progression)
  }

  ## Calculate the smallest distance between any two time values other than 0
  stime <- sort(time)
  diff <- stime[-1] - stime[-length(stime)]
  min_diff <- min(diff[diff != 0])

  ## Add small values to the time points. If there are time points with same values, samples will now be ordered randomly.
  noises <- stats::runif(length(time), 0, 0.01 * min_diff)
  noised_time <- time + noises

  ## Rank the time points
  rank <- rank(noised_time)

  ## satisfying r cmd check
  i <- j <- pri <- prj <- rai <- raj <- NA

  ## Calculate whether or not pairs of samples are consistent in terms of its progression and rank
  comp <-
    crossing(
      i = seq_along(progression),
      j = seq_along(progression)
    ) %>%
    mutate(
      pri = progression[i],
      prj = progression[j],
      rai = rank[i],
      raj = rank[j],
      consistent = (pri < prj) == (rai < raj)
    ) %>%
    filter(pri != prj)

  ## Calculate the mean consistency
  con <- mean(comp$consistent)

  ## Take into account undirectionality of the timeline
  con <- max(con, 1 - con)

  ## Rescale and return
  (con - .5) * 2
}

#' @title Evaluate the dimensionality reduction
#'
#' @description \code{evaluate_dim_red} calculates the \emph{accuracy} of the
#' dimensionality reduction by performing 5-nearest neighbour leave-one-out-cross-validation (5NN LOOCV).
#'
#' @usage
#' evaluate_dim_red(space, progression, k=5)
#'
#' @param space A numeric vector containing the inferred time points of each sample along a trajectory.
#' @param progression A factor or a numeric vector which represents the progression stages of each sample.
#' @param k The maximum number of nearest neighbours to search (default 5).
#'
#' @return The accuracy of a 5NN LOOCV using the dimensionality reduction to predict the progression stage of a sample.
#'
#' @export
#'
#' @importFrom stats dist
#'
#' @examples
#' ## Generate a dataset
#' dataset <- generate_dataset(type="s", num_genes=500, num_samples=300, num_groups=4)
#' space <- reduce_dimensionality(dataset$expression, correlation_distance, ndim=2)
#'
#' ## Evaluate the trajectory timeline
#' evaluate_dim_red(space, dataset$sample_info$group_name)
evaluate_dim_red <- function(space, progression, k = 5) {
  # input checks
  check_numeric_matrix(space, "space", finite = TRUE)
  check_numeric_vector(k, "k", finite = TRUE, whole = TRUE, range = c(1, nrow(space) - 1), length = 1)
  check_numeric_vector(progression, "progression", finite = TRUE, factor = TRUE, whole = TRUE)

  if (nrow(space) != length(progression))
    stop(sQuote("nrow(space)"), " and ", sQuote("length(progression)"), " must be the same.")

  # if progression is a factor, convert it to an integer
  if (is.factor(progression)) {
    progression <- as.integer(progression)
  }

  # perform 5NN LOOCV
  knn_out <- knn(as.matrix(stats::dist(space)), k = k)

  multi_mode <- sapply(seq_along(progression), function(i) {
    z <- progression[knn_out$indices[i,]]
    cdf <- dplyr::count(data.frame(z), z)
    modes <- cdf$z[cdf$n == max(cdf$n)]
    progression[[i]] %in% modes
  })

  mean(multi_mode)
}
