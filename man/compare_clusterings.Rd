% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/compare-clusterings.R
\name{compare_clusterings}
\alias{compare_clusterings}
\title{Compare different clustering configurations}
\usage{
compare_clusterings(series = NULL, types = c("p", "h", "f", "t"), ...,
  configs = compare_clusterings_configs(types), seed = NULL,
  trace = FALSE, score.clus = function(...) stop("No scoring"),
  pick.clus = function(...) stop("No picking"), shuffle.configs = FALSE,
  return.objects = FALSE, packages = character(0L),
  .errorhandling = "stop")
}
\arguments{
\item{series}{A list of series, a numeric matrix or a data frame. Matrices and data frames are
coerced to a list row-wise.}

\item{types}{Clustering types. It must be any combination of (possibly abbreviated): partitional,
hierarchical, fuzzy, tadpole.}

\item{...}{Further arguments for \code{\link[=tsclust]{tsclust()}}, \code{score.clus} or \code{pick.clus}.}

\item{configs}{The list of data frames with the desired configurations to run. See
\code{\link[=pdc_configs]{pdc_configs()}} and \code{\link[=compare_clusterings_configs]{compare_clusterings_configs()}}.}

\item{seed}{Seed for random reproducibility.}

\item{trace}{Logical indicating that more output should be printed to screen.}

\item{score.clus}{A function that gets the list of results (and \code{...}) and scores each one. It
may also be a named list of functions, one for each type of clustering. See Scoring section.}

\item{pick.clus}{A function that gets the result from \code{score.clus} as first argument, as well as
the objects returned by \code{\link[=tsclust]{tsclust()}} (and elements of \code{...}) and picks the best result.}

\item{shuffle.configs}{Randomly shuffle the order of configs, which can be useful to balance load
when using parallel computation.}

\item{return.objects}{Logical indicating whether the objects from returned by \code{\link[=tsclust]{tsclust()}} should
be given in the result.}

\item{packages}{A character vector with the names of any packages needed for any functions used
(distance, centroid, preprocessing, etc.). The name "dtwclust" is added automatically. Relevant
for parallel computation.}

\item{.errorhandling}{This will be passed to \code{\link[foreach:foreach]{foreach::foreach()}}. See Parallel section below.}
}
\value{
A list with:
\itemize{
\item \code{results}: A list of data frames with the flattened configs and the corresponding scores
returned by \code{score.clus}.
\item \code{scores}: The scores given by \code{score.clus}.
\item \code{pick}: The object returned by \code{pick.clus}.
\item \code{proc_time}: The measured execution time, using \code{\link[base:proc.time]{base::proc.time()}}.
}

The cluster objects are also returned if \code{return.objects} \code{=} \code{TRUE}.
}
\description{
Compare many different clustering algorithms with support for parallelization.
}
\details{
This function calls \code{\link[=tsclust]{tsclust()}} with different configurations and evaluates the results with the
provided functions. Parallel support is included. See the examples.

Parameters specified in \code{configs} whose values are \code{NA} will be ignored automatically.

The scoring and picking functions are for convenience, if they are not specified, the \code{scores}
and \code{pick} elements of the result will be \code{NULL}.
}
\section{Parallel computation}{


The configurations for each clustering type can be evaluated in parallel with the \pkg{foreach}
package. A parallel backend can be registered, e.g., with \pkg{doParallel}.

If the \code{.errorhandling} parameter is changed to "pass" and a custom \code{score.clus} function is
used, said function should be able to deal with possible error objects.

If it is changed to "remove", it might not be possible to attach the scores to the results data
frame, or it may be inconsistent. Additionally, if \code{return.objects} is \code{TRUE}, the names given
to the objects might also be inconsistent.
}

\section{Scoring}{


The clustering results are organized in a \emph{list of lists} in the following way (where only
applicable \code{types} exist; first-level list names in bold):
\itemize{
\item \strong{partitional} - list with
\itemize{
\item Clustering results from first partitional config
\item etc.
}
\item \strong{hierarchical} - list with
\itemize{
\item Clustering results from first hierarchical config
\item etc.
}
\item \strong{fuzzy} - list with
\itemize{
\item Clustering results from first fuzzy config
\item etc.
}
\item \strong{tadpole} - list with
\itemize{
\item Clustering results from first tadpole config
\item etc.
}
}

If \code{score.clus} is a function, it will be applied to the available partitional, hierarchical,
fuzzy and/or tadpole results via:\preformatted{scores <- lapply(list_of_lists, score.clus, ...)
}

Otherwise, \code{score.clus} should be a list of functions with the same names as the list above,
so that \code{score.clus$partitional} is used to score \code{list_of_lists$partitional} and so on (via
\code{\link[base:mapply]{base::mapply()}} with \code{SIMPLIFY} \code{=} \code{FALSE}).

Therefore, the scores returned shall always be a list of lists with first-level names as above.
}

\section{Picking}{


\strong{Please note that this functionality was slightly modified in version 4.0.0 of dtwclust.}

If \code{return.objects} is \code{TRUE}, the scores and the list of clustering results are given to
\code{pick.clus} as first and second arguments respectively, followed by \code{...}. Otherwise,
\code{pick.clus} will receive only the scores and the contents of \code{...} (since the results will not
be returned by the preceding step).
}

\examples{
## Fuzzy preprocessing: calculate autocorrelation up to 50th lag
acf_fun <- function(dat, ...) {
    lapply(dat, function(x) {
        as.numeric(acf(x, lag.max = 50, plot = FALSE)$acf)
    })
}

## Define overall configuration
cfgs <- compare_clusterings_configs(
    types = c("p", "h", "f", "t"),
    k = 19L:20L,
    controls = list(
        partitional = partitional_control(
            iter.max = 30L,
            nrep = 1L
        ),
        hierarchical = hierarchical_control(
            method = "all"
        ),
        fuzzy = fuzzy_control(
            ## notice the vector
            fuzziness = c(2, 2.5),
            iter.max = 30L
        ),
        tadpole = tadpole_control(
            ## notice the vectors
            dc = c(1.5, 2),
            window.size = 19L:20L
        )
    ),
    preprocs = pdc_configs(
        type = "preproc",
        ## shared
        none = list(),
        zscore = list(center = c(FALSE)),
        ## only for fuzzy
        fuzzy = list(
            acf_fun = list()
        ),
        ## only for tadpole
        tadpole = list(
            reinterpolate = list(new.length = 205L)
        ),
        ## specify which should consider the shared ones
        share.config = c("p", "h")
    ),
    distances = pdc_configs(
        type = "distance",
        sbd = list(),
        fuzzy = list(
            L2 = list()
        ),
        share.config = c("p", "h")
    ),
    centroids = pdc_configs(
        type = "centroid",
        partitional = list(
            pam = list()
        ),
        ## special name 'default'
        hierarchical = list(
            default = list()
        ),
        fuzzy = list(
            fcmdd = list()
        ),
        tadpole = list(
            default = list(),
            shape_extraction = list(znorm = TRUE)
        )
    )
)

## Number of configurations is returned as attribute
num_configs <- sapply(cfgs, attr, which = "num.configs")
cat("\\nTotal number of configurations without considering optimizations:",
    sum(num_configs),
    "\\n\\n")

## Define evaluation function based on CVI: Variation of Information
score_fun <- function(obj_list, ...) {
    sapply(obj_list, function(obj) {
        cvi(obj@cluster, CharTrajLabels, type = "VI")
    })
}

## Function that chooses best result
pick_fun <- function(scores, obj_lists, ...) {
    best_considering_type <- sapply(scores, which.min)
    best_overall <- which.min(mapply(scores, best_considering_type,
                                     FUN = function(score, id) { score[id] }))

    best_obj <- obj_lists[[best_overall]][[best_considering_type[best_overall]]]

    ## return
    best_obj
}

# ====================================================================================
# Short run with only fuzzy clustering
# ====================================================================================

comparison_short <- compare_clusterings(CharTraj, types = c("f"), configs = cfgs,
                                        seed = 293L, trace = TRUE,
                                        score.clus = score_fun, pick.clus = pick_fun,
                                        return.objects = TRUE)

\dontrun{
# ====================================================================================
# Parallel run with all comparisons
# ====================================================================================

require(doParallel)
registerDoParallel(cl <- makeCluster(detectCores()))

comparison_long <- compare_clusterings(CharTraj, types = c("p", "h", "f", "t"),
                                       configs = cfgs,
                                       seed = 293L, trace = TRUE,
                                       score.clus = score_fun,
                                       pick.clus = pick_fun,
                                       return.objects = TRUE)

# ------------------------------------------------------------------------------------
# Using all external CVIs and majority vote
# ------------------------------------------------------------------------------------

score_external <- function(obj_list, ...) {
    scores <- lapply(obj_list, function(obj) {
        indices <- cvi(obj@cluster, CharTrajLabels, type = "external")

        ## invert VI to consider maximization
        indices["VI"] <- 1 / indices["VI"]

        ## return
        indices
    })

    ## return
    do.call(rbind, scores)
}

pick_majority <- function(scores, obj_lists, ...) {
    majority <- function(x) {
        ux <- unique(x)
        ux[which.max(tabulate(match(x, ux)))]
    }

    best_considering_type <- sapply(scores, function(score) {
        best_by_cvi <- apply(score, 2L, which.max)
        majority(best_by_cvi)
    })

    best_cvis_overall <- do.call(rbind,
                                 mapply(scores, best_considering_type,
                                        SIMPLIFY = FALSE,
                                        FUN = function(score, row_id) {
                                            score[row_id, , drop = FALSE]
                                        }))

    best_overall <- majority(apply(best_cvis_overall, 2L, which.max))

    best_obj <- obj_lists[[best_overall]][[best_considering_type[best_overall]]]

    ## to find config later, see 'best config' below
    attr(best_obj, "config_id") <- c(best_overall,
                                     best_considering_type[best_overall])

    ## return
    best_obj
}

comparison_majority <- compare_clusterings(CharTraj, types = c("p", "h", "f", "t"),
                                           configs = cfgs,
                                           seed = 84L, trace = TRUE,
                                           score.clus = score_external,
                                           pick.clus = pick_majority,
                                           return.objects = TRUE)

plot(comparison_majority$pick)

## best config
config_id <- attr(comparison_majority$pick, "config_id")
print(comparison_majority$results[[config_id[1L]]][config_id[2L], , drop = FALSE])

stopCluster(cl); registerDoSEQ()

# ====================================================================================
# A run with only partitional clusterings
# ====================================================================================

p_cfgs <- compare_clusterings_configs(types = "p", k = 19L:21L,
                                      controls = list(
                                          partitional = partitional_control(
                                              iter.max = 20L,
                                              nrep = 8L
                                          )
                                      ),
                                      preprocs = pdc_configs(
                                          "preproc",
                                          none = list(),
                                          zscore = list(center = c(FALSE, TRUE))
                                      ),
                                      distances = pdc_configs(
                                          "distance",
                                          sbd = list(),
                                          dtw_basic = list(window.size = 19L:20L,
                                                           norm = c("L1", "L2")),
                                          gak = list(window.size = 19L:20L,
                                                     sigma = 100)
                                      ),
                                      centroids = pdc_configs(
                                          "centroid",
                                          partitional = list(
                                              pam = list(),
                                              shape = list()
                                          )
                                      )
)

# Remove redundant (shape centroid always uses zscore preprocessing)
id_redundant <- p_cfgs$partitional$preproc == "none" &
    p_cfgs$partitional$centroid == "shape"
p_cfgs$partitional <- p_cfgs$partitional[!id_redundant, ]

# LONG! 20 minutes or so, sequentially
comparison_partitional <- compare_clusterings(CharTraj, types = "p",
                                              configs = p_cfgs,
                                              seed = 32903L, trace = TRUE,
                                              score.clus = score_fun,
                                              pick.clus = pick_fun,
                                              shuffle.configs = TRUE,
                                              return.objects = TRUE)
}
}
\seealso{
\code{\link[=compare_clusterings_configs]{compare_clusterings_configs()}}, \code{\link[=tsclust]{tsclust()}}
}
\author{
Alexis Sarda-Espinosa
}
