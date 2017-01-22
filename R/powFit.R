#' Generalized Power (or Box-Cox) Transformation.
#'
#' @param x Vector of values at which to compute the transformation.
#' @param lambda Exponent of the transformation.  See details.
#' @param alpha Offset of the transformation.  See details.
#' @param normalize Logical; if TRUE divides by the geometric mean.  See details.
#' @param jacobian Logical; if TRUE calculates the Jacobian \code{|dz / dx|}, which converts transformed density values back to the original scale.
#' @details The Generalized Power or Box-Cox transformation is
#' \deqn{\code{z = ((x + alpha)^lambda - 1) / (lambda * C^(lambda-1))}, \code{lambda != 0},}
#' \deqn{\code{z = C * log(x + alpha)}, \code{lambda == 0},}
#' where \code{C} is the Geometric mean:
#' \deqn{\code{C = exp(mean(log(x + alpha)))}.}
#' Note that \code{C} is only calculated if \code{normalize = TRUE}.
#' @return The vector \code{z} of transformed values, and optionally the Jacobian of the inverse transformation.  See details.
#' @export
pow.trans <- function(x, lambda = 0, alpha = 0, normalize = FALSE,
                      jacobian = FALSE, debug = FALSE) {
  if(lambda == 0) z <- log(x + alpha) else z <- ((x + alpha)^lambda - 1)/lambda
  if(debug) browser()
  if(normalize) {
    gm <- exp(mean(log(x)))
    if(lambda == 0) K <- gm else K <- 1/gm^(lambda-1)
  } else K <- 1
  ans <- z * K
  if(jacobian) ans <- list(z = ans, jacobian = (x + alpha)^(lambda - 1) * K)
  ans
}

#' Maximum Likelihood Estimate of the Generalized Power Transform.
#'
#' @param x Vector of samples from density.
#' @param alpha Optional value of the offset parameter.  \code{alpha = FALSE} sets \code{alpha = 1 - min(x)}, thereby guaranteeing that \code{z = x + alpha >= 1}.  This or any scalar value of \code{alpha} optimizes as a function of \code{lambda} only.  \code{alpha = NA} jointly optimizes for \code{lambda} and \code{alpha}.
#' @param interval Range of \code{lambda} values for one dimensional optimization.
#' @param ... Additional arguments to pass to \code{optimize} or \code{optim}, for 1- or 2-parameter optimization.
#' @details The likelihood for optimization is
#' \deqn{\code{L(lambda, alpha | x) = prod(dnorm(z(x | lambda, alpha)) *  |dz(x | lambda, alpha) / dx|)},}
#' where \code{z(x | lambda, alpha)} is the Box-Cox transformation.
#' @return MLEs for \code{lambda} and possibly \code{alpha} as well.
powFit <- function(x, alpha = NA, interval = c(-5, 5), ..., debug = FALSE) {
 n <- length(x)
 mx <- min(x)
 fl <- function(lambda) {
   z <- pow.trans(x = x, lambda = lambda, alpha = 0)
   s2 <- var(z)*(n-1)/n
   -n/2 * log(s2) + (lambda-1) * lx
 }
 fal <- function(theta) {
   if(theta[1] + mx <= 0) return(-Inf)
   z <- pow.trans(x = x, lambda = theta[2], alpha = theta[1])
   s2 <- var(z)*(n-1)/n
   -n/2 * log(s2) + (theta[2]-1) * sum(log(x + theta[1]))
 }
 if(debug) browser()
 if(!is.na(alpha)) {
   # 1-parameter optimization
   if(is.logical(alpha) && !alpha) alpha <- 1 - mx
   x <- x + alpha
   lx <- sum(log(x))
   ans <- c(alpha = alpha,
            lambda = optimize(fl, interval = interval, maximum = TRUE)$maximum)
 } else {
   # 2-parameter optimization
   ans <- optim(par = c(1 - mx, 0), fn = fal, control = list(fnscale = -1, ...))
   if(ans$convergence != 0) stop("optim failed to converge.")
   ans <- ans$par
   names(ans) <- c("alpha", "lambda")
 }
 ans
}