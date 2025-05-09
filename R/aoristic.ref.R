#' Hour of the week reference chart
#'
#' Creates and views a simple data frame with reference hour of the week. 
#' This is a reference for the aoristic.map function that requires a user-selected hour
#' in order to map spatial distribution for the requested one hour time period. 
#' 
#' NOTE: The jpg from aoristic.summary does not use the same day/hour layout. 
#' Sunday is moved to the end of the layout to make the weekend period clearer to the user. 
#' 
#' @return A data frame
#' @export
#' @references Ratcliffe, J. H. (2002). Aoristic signatures and the spatio-temporal analysis of high volume crime patterns. Journal of Quantitative Criminology, 18(1), 23-43.

aoristic.ref <- function() {
    
    View <- NULL #prevents R CMD check flagging 'no visible global function definition'
    
    hour.reference <- data.frame(matrix(0, ncol = 7, nrow = 24))
    colnames(hour.reference) <- c("So", "Mo", "Di", "Mi", "Do", "Fr", "Sa")
    Range <- c("0000-0059", "0000-0159", "0200-0259", "0300-0359", "0400-0459", "0500-0559", "0600-0659", 
        "0700-0759", "0800-0859", "0900-0959", "1000-1059", "1100-1159", "1200-1259", "1300-1359", "1400-1459", 
        "1500-1559", "1600-1659", "1700-1759", "1800-1859", "1900-1959", "2000-2059", "2100-2159", "2200-2259", 
        "2300-2359")
    df7 <- data.frame(Range)
    hour.reference <- data.frame(df7, hour.reference)
    rm(df7)
    h.row <- 1
    h.col <- 2
    for (i in 1:168) {
        hour.reference[h.row, h.col] <- i
        h.row <- h.row + 1
        if (h.row == 25) {
            h.row <- 1
            h.col <- h.col + 1
        }
    }
    View(hour.reference, "Aoristic hour reference")
    
    return(hour.reference)
    
}
