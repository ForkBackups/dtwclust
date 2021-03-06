% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tsclust-classes.R
\docType{class}
\name{tsclustFamily-class}
\alias{tsclustFamily-class}
\title{Class definition for \code{tsclustFamily}}
\description{
Formal S4 class with a family of functions used in \code{\link[=tsclust]{tsclust()}}.
}
\details{
The custom implementations also handle parallelization.

Since the distance function makes use of \code{proxy}, it also supports any extra \code{\link[proxy:dist]{proxy::dist()}}
parameters in \code{...}.

The prototype includes the \code{cluster} function for partitional methods, as well as a pass-through
\code{preproc} function.
}
\section{Slots}{

\describe{
\item{\code{dist}}{The function to calculate the distance matrices.}

\item{\code{allcent}}{The function to calculate centroids on each iteration.}

\item{\code{cluster}}{The function used to assign a series to a cluster.}

\item{\code{preproc}}{The function used to preprocess the data (relevant for \code{\link[stats:predict]{stats::predict()}}).}
}}

\examples{

# The dist() function in tsclustFamily works like proxy::dist() but supports
# parallelization and optimized symmetric calculations. If you like, you can
# use the function more or less directly, but provide a control argument when
# creating the family.

\dontrun{
data(uciCT)
fam <- new("tsclustFamily", dist = "gak",
           control = partitional_control(symmetric = TRUE))

crossdist <- fam@dist(CharTraj, window.size = 18L)
}

# If you want the fuzzy family, use fuzzy = TRUE
ffam <- new("tsclustFamily", control = fuzzy_control(), fuzzy = TRUE)


}
