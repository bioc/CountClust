#' @title Run Grade of Membership (GoM) model with multiple starting points !
#'
#' @description Fits grade of membership model \code{FitGoM()} to count data
#'        with multiple starting points and choose the best fit using BIC (Bayesian
#'        Information Criterion). the multiple starting points ensure that
#'        the output is more reliable.
#'
#' @param data counts data \eqn{N x G}, with \eqn{N}, the number of samples
#'       along the rows and \eqn{G}, number of genes along columns.
#' @param K the vector of clusters or topics to be fitted. Must be an integer,
#'       unlike in ]\code{FitGom()}. So you need to apply this function separately
#'       for each K.
#' @param tol Tolerance value for GoM model absolute log posterior increase
#'            at successive iterations (set to 0.1 as default).
#' @param num_trials The number of trials with different starting points used.
#' @param options the measure used to choose best fit, either "BF" or "BIC" measures can be used.
#'        BF is more trustworthy, but BIC can be used for better model comparison.
#' @param path_rda The directory path for saving the GoM model output.
#'                  If NULL, it will return the output to console.
#' @param control Control parameters for the GoM model fits. Same as topics() function of
#'                 maptpx package.
#'
#' @return Outputs the best GoM model fit output for cluster K and saves it
#'         at the directory path in path_rda if the latter is provided.
#'
#' @references Matt Taddy. On Estimation and Selection for Topic Models.
#'                AISTATS 2012, JMLR W\&CP 22.
#'
#'            Pritchard, Jonathan K., Matthew Stephens, and Peter Donnelly.
#'                Inference of population structure using multilocus genotype
#'                data. Genetics 155.2 (2000): 945-959.
#'
#' @keywords counts data, clustering, Structure plot
#'
#'
#' @examples
#'
#' data("ex.counts")
#' out <- FitGoM(ex.counts, K=2, tol=100, num_trials=5,
#'                    control=list(tmax=100))
#'
#' @importFrom maptpx topics
#' @import slam
#' @importFrom utils modifyList
#' @import SQUAREM
#' @export
#'

FitGoM <- function(data,
                   K,
                   tol=0.1,
                   num_trials = 1,
                   options,
                   path_rda = NULL,
                   control=list())
{
  if(missing(options)){
      message("options not specified: switching to default BIC, other choice is BF for Bayes factor")
      options <- "BIC"
  }
  if(length(K) > 1)
    stop("For FitGoMpool, K must be an integer, run for separate K")

  out <- list()

  control.default <- list(shape=NULL, initopics=NULL, bf=TRUE,
                          kill=2, ord=TRUE, verb=1, admix=TRUE,
                          tmax=1000)
  namc=names(control)
  if (!all(namc %in% names(control.default)))
      stop("unknown names in control: ",
           namc[!(namc %in% names(control.default))])
  control <- modifyList(control.default, control)


  for(num in 1:num_trials){
    out[[num]] <- do.call(FitGoM_skeleton, list(data = as.matrix(data),
                                       K=K,
                                       tol=tol,
                                       control = control))
  }

  if(options=="BIC"){
        BIC_val <- array(0, num_trials)
        for(n in 1:length(BIC_val)){
            BIC_val [n] <- compGoM(data, out[[n]])[[1]]$BIC
        }

        Topic_clus <- out[[which.min(BIC_val)]][[1]]
        ll <- list("fit"=Topic_clus,
                   "BIC"=BIC_val[which.min(BIC_val)])
  }

  if(options=="BF"){
      BF_val <- array(0, num_trials);
      for(n in 1:length(BF_val)){
          BF_val [n] <- as.numeric(out[[n]][[1]]$BF);
      }

      Topic_clus <- out[[which.max(BF_val)]][[1]]
      ll <- list("fit"=Topic_clus,
                 "BF"=BF_val[which.max(BF_val)])
  }


  if(!is.null(path_rda)){
    save(Topic_clus, file = path_rda);
     return(ll)
  }else{
     return(ll)
  }
}



FitGoM_skeleton <- function(data,
                   K,
                   tol=0.1,
                   control=list())
{
    ## dealing with blank rows: we first remove them

    control.default <- list(shape=NULL, initopics=NULL, bf=TRUE,
                            kill=2, ord=TRUE, verb=1, admix=TRUE,
                            tmax=1000)

    namc=names(control)
    if (!all(namc %in% names(control.default)))
        stop("unknown names in control: ",
             namc[!(namc %in% names(control.default))])
    control=modifyList(control.default, control)



    indices_blank <- as.numeric(which(apply(data,1,max) == 0))
    if(length(indices_blank)!=0){
        data <- as.matrix(data[-indices_blank,]);
    }

    message('Fitting a Grade of Membership model
            (Taddy M., AISTATS 2012, JMLR 22,
            http://proceedings.mlr.press/v22/taddy12/taddy12.pdf)',
            domain = NULL, appendLF = TRUE)

    Topic_clus_list <- lapply(K, function(per_clust) {

        suppressWarnings(out <- do.call(maptpx::topics, append(list(counts = as.matrix(data),
                                                                    K = per_clust, tol = tol), control)))
        return(out)
    })

    names(Topic_clus_list) <- paste0("clust_",K)
    return(Topic_clus_list)
}
