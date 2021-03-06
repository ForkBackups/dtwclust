#' DTW Barycenter Averaging
#'
#' A global averaging method for time series under DTW (Petitjean, Ketterlin and Gancarski 2011).
#'
#' @export
#'
#' @param X A matrix or data frame where each row is a time series, or a list where each element is
#'   a time series. Multivariate series should be provided as a list of matrices where time spans
#'   the rows and the variables span the columns of each matrix.
#' @param centroid Optionally, a time series to use as reference. Defaults to a random series of `X`
#'   if `NULL`. For multivariate series, this should be a matrix with the same characteristics as
#'   the matrices in `X`.
#' @param ... Further arguments for [dtw_basic()]. However, the following are already pre-
#'   specified: `window.size`, `norm` (passed along), and `backtrack`.
#' @param window.size Window constraint for the DTW calculations. `NULL` means no constraint. A
#'   slanted band is used by default.
#' @param norm Norm for the local cost matrix of DTW. Either "L1" for Manhattan distance or "L2" for
#'   Euclidean distance.
#' @param max.iter Maximum number of iterations allowed.
#' @param delta At iteration `i`, if `all(abs(centroid_{i}` `-` `centroid_{i-1})` `< delta)`,
#'   convergence is assumed.
#' @template error-check
#' @param trace If `TRUE`, the current iteration is printed to output.
#' @param gcm Optional matrix to pass to [dtw_basic()] (for the case when `backtrack = TRUE`). To
#'   define the matrix size, it should be assumed that `x` is the *longest* series in `X`, and `y`
#'   is the `centroid` if provided or `x` otherwise. Ignored in parallel computations.
#' @param mv.ver Multivariate version to use. See below.
#'
#' @details
#'
#' This function tries to find the optimum average series between a group of time series in DTW
#' space. Refer to the cited article for specific details on the algorithm.
#'
#' If a given series reference is provided in `centroid`, the algorithm should always converge to
#' the same result provided the elements of `X` keep the same values, although their order may
#' change.
#'
#' @template window
#'
#' @return The average time series.
#'
#' @section Multivariate series:
#'
#'   There are currently 2 versions of DBA implemented for multivariate series:
#'
#'   - If `mv.ver = "by-variable"`, then each variable of `X` and `centroid` are extracted, and the
#'     univariate version of the algorithm is applied to each set of variables, binding the results
#'     by column. Therefore, the DTW backtracking is different for each variable.
#'   - If `mv.ver = "by-series"`, then all variables are considered at the same time, so the DTW
#'     backtracking is computed based on each multivariate series as a whole. This version was
#'     implemented in version 4.0.0 of \pkg{dtwclust}, and it might be faster.
#'
#' @template parallel
#'
#' @note
#'
#' The indices of the DTW alignment are obtained by calling [dtw_basic()] with `backtrack = TRUE`.
#'
#' @references
#'
#' Petitjean F, Ketterlin A and Gancarski P (2011). ``A global averaging method for dynamic time
#' warping, with applications to clustering.'' *Pattern Recognition*, **44**(3), pp. 678 - 693. ISSN
#' 0031-3203, \url{http://dx.doi.org/10.1016/j.patcog.2010.09.013},
#' \url{http://www.sciencedirect.com/science/article/pii/S003132031000453X}.
#'
#' @examples
#'
#' # Sample data
#' data(uciCT)
#'
#' # Obtain an average for the first 5 time series
#' dtw.avg <- DBA(CharTraj[1:5], CharTraj[[1]], trace = TRUE)
#'
#' # Plot
#' matplot(do.call(cbind, CharTraj[1:5]), type = "l")
#' points(dtw.avg)
#'
#' # Change the provided order
#' dtw.avg2 <- DBA(CharTraj[5:1], CharTraj[[1]], trace = TRUE)
#'
#' # Same result?
#' all(dtw.avg == dtw.avg2)
#'
#' \dontrun{
#' #### Running DBA with parallel support
#' # For such a small dataset, this is probably slower in parallel
#' require(doParallel)
#'
#' # Create parallel workers
#' cl <- makeCluster(detectCores())
#' invisible(clusterEvalQ(cl, library(dtwclust)))
#' registerDoParallel(cl)
#'
#' # DTW Average
#' cen <- DBA(CharTraj[1:5], CharTraj[[1]], trace = TRUE)
#'
#' # Stop parallel workers
#' stopCluster(cl)
#'
#' # Return to sequential computations
#' registerDoSEQ()
#' }
#'
DBA <- function(X, centroid = NULL, ...,
                window.size = NULL, norm = "L1",
                max.iter = 20L, delta = 1e-3,
                error.check = TRUE, trace = FALSE,
                gcm = NULL, mv.ver = "by-variable")
{
    X <- any2list(X)
    mv.ver <- match.arg(mv.ver, c("by-variable", "by-series"))

    if (is.null(centroid)) centroid <- X[[sample(length(X), 1L)]] # Random choice
    if (error.check) {
        check_consistency(X, "vltslist")
        check_consistency(centroid, "ts")
    }

    ## utils.R
    mv <- is_multivariate(X)
    if (mv && mv.ver == "by-variable") {
        mv <- reshape_multivariate(X, centroid) # utils.R

        new_c <- Map(
            mv$series, mv$cent, f = function(xx, cc) {
                DBA(xx, cc, ...,
                    norm = norm,
                    window.size = window.size,
                    max.iter = max.iter,
                    delta = delta,
                    error.check = FALSE,
                    trace = trace)
            }
        )

        new_c <- do.call(cbind, new_c)
        dimnames(new_c) <- dimnames(centroid)
        return(new_c)

    } else {
        X <- lapply(X, cbind)
        centroid <- cbind(centroid)
    }

    if (!is.null(window.size)) window.size <- check_consistency(window.size, "window")
    norm <- match.arg(norm, c("L1", "L2"))
    dots <- list(...)
    L <- max(sapply(X, NROW)) + 1L ## maximum length of considered series + 1L
    Xs <- split_parallel(X)

    ## pre-allocate cost matrices
    if (is.null(gcm))
        gcm <- matrix(0, L, NROW(centroid) + 1L)
    else if (!is.matrix(gcm) || nrow(gcm) < (L) || ncol(gcm) < (NROW(centroid) + 1L))
        stop("DBA: Dimension inconsistency in 'gcm'")
    else if (storage.mode(gcm) != "double")
        stop("DBA: If provided, 'gcm' must have 'double' storage mode.")

    ## All extra parameters for dtw_basic()
    dots <- enlist(window.size = window.size,
                   norm = norm,
                   gcm = gcm,
                   backtrack = TRUE,
                   dots = dots)

    ## Iterations
    iter <- 1L
    centroid_old <- centroid
    if (trace) cat("\tDBA Iteration:")

    while (iter <= max.iter) {
        ## Return the coordinates of each series in X grouped by the coordinate they match to in the
        ## centroid time series.
        ## Also return the number of coordinates used in each case (for averaging below).
        xg <- foreach::foreach(
            X = Xs,
            .combine = c,
            .multicombine = TRUE,
            .export = "enlist",
            .packages = c("dtwclust", "stats")
        ) %op% {
            lapply(X, function(x) {
                d <- do.call(dtw_basic, enlist(x = x, y = centroid, dots = dots))
                x_sub <- stats::aggregate(x[d$index1, ], by = list(ind = d$index2), sum)
                n_sub <- stats::aggregate(x[d$index1, ], by = list(ind = d$index2), length)
                data.frame(".id_var" = 1L:nrow(x_sub), x_sub[, -1L], ".n" = n_sub[, 2L])
            })
        }

        ## Put everything in one big data frame
        xg <- reshape2::melt(xg, id.vars = ".id_var")
        ## Aggregate by summing according to index of centroid time series
        xg <- reshape2::dcast(xg, .id_var ~ variable, fun.aggregate = sum, value.var = "value")
        ## Average
        centroid <- base::as.matrix(xg[setdiff(colnames(xg), c(".id_var", ".n"))] / xg$.n)

        if (isTRUE(all.equal(centroid, centroid_old, tolerance = delta))) {
            if (trace) cat("", iter, "- Converged!\n")
            break

        } else {
            if (trace) {
                cat(" ", iter, ",", sep = "")
                if (iter %% 10 == 0) cat("\n\t\t")
            }

            centroid_old <- centroid
            iter <- iter + 1L
        }
    }

    if (iter > max.iter && trace) cat(" Did not 'converge'\n")
    if (mv) centroid else base::as.numeric(centroid)
}
