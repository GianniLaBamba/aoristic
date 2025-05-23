#' Calculate aoristic weights
#' 
#' Calculates aoristic proportional weights across 168 units representing each hour of the week (24 hours x 7 days). 
#' It is designed for situations when an event time is not know but could be spread across numerous
#' hours or days, and is represented by a Start (or From) date and time, and an End (or To) date and time.
#' The output retains the source data, and can be reimported into a GIS for spatial analysis. The output 
#' from this function is used in other aoristic library functions. 
#' 
#' NOTE: If an observation is missing the End/To datetime, the entire aoristic weight (1.0) will be assigned to the
#' hour block containing the Start/From datetime. Events with start datetime events after the end datetime will also 
#' be assigned to the hour block containing the Start/From datetime. Events with time spans lasting more than one 
#' week (>168 hours) will default to a time span of 168 hours and a value of ~ 0.0059 (1/168) assigned to each day/hour.
#' 
#'
#' @param data1 data frame with a minimum of 4 columns with X, Y coords, Start and End date/time
#' @param Xcoord a vector of the event X coordinate or latitude (numeric object)
#' @param Ycoord a vector of the event Y coordinate or longitude (numeric object)
#' @param DateTimeFrom a vector of the column name for FromDateTime (POSIXct date-time object)
#' @param DateTimeTo a vector of the column name for ToDateTime (POSIXct date-time object) 
#' @return A data frame with aoristic values for each hour of the week for each observation
#' @import lubridate
#' @examples 
#' df <- aoristic.df(dcburglaries, 'X', 'Y', 'StartDateTime', 'EndDateTime')
#' @export
#' @references Ratcliffe, J. H. (2002). Aoristic signatures and the spatio-temporal analysis of high volume crime patterns. Journal of Quantitative Criminology, 18(1), 23-43.
#'
#'

aoristic.df <- function
(data1, Xcoord, Ycoord, DateTimeFrom, DateTimeTo) {
  
  
  # BUGHUNT - used for JHR debugging purposes only
  bughunt <- F 
  DCburg <- NYburg <- NULL

  
  if (bughunt){ 
    testset <- 1
    if (testset == 1)
    {
      data1 <- DCburg
      Xcoord <- 'XCOORD'
      Ycoord <- 'YCOORD'
      DateTimeFrom <- 'STARTDateTime'
      DateTimeTo <- 'ENDDateTime'
    } else {
      data1 <- NYburg
      Xcoord <- 'X_COORD_CD'
      Ycoord <- 'Y_COORD_CD'
      DateTimeFrom <- 'STARTDateTime'
      DateTimeTo <- 'ENDDateTime'
    }
  } #/BUGHUNT
  
  
  
  if (!is.data.frame(data1)) {
    stop("The input data frame specified is not a data.frame object")
  }
  
  # Build a local data.frame and populate with passed arguments
  x_lon <- y_lat <- x <- NULL
  errors.unfixable <- errors.rogue <- errors.logic <- errors.missing <- 0
  
  
  df1 <- data.frame(matrix(ncol = 4, nrow = nrow(data1)))
  colnames(df1) <- c("x_lon", "y_lat", "datetime_from", "datetime_to")
  df1$x_lon <- data1[, Xcoord]
  df1$y_lat <- data1[, Ycoord]
  df1$datetime_from <- data1[, DateTimeFrom]
  df1$datetime_to <- data1[, DateTimeTo]
  myMessages <- "T"
  
  
  if (!class(df1$datetime_from)[1] == "POSIXct") {
    stop("The DateTimeFrom field is not a POSIXct object. Convert with the lubridate package before using this function")
  }
  if (!class(df1$datetime_to)[1] == "POSIXct") {
    stop("The DateTimeTo field is not a POSIXct object. Convert with the lubridate package before using this function")
  }
  
  suppressWarnings (duration <- as.duration(ymd_hms(df1$datetime_from) %--% ymd_hms(df1$datetime_to)))
  df1$duration <- duration %/% dminutes(1)  # This is the modelo exact duration in minutes, rounded down
  
  
  # Deal with errors in crime duration -------------------------------------
  
  # DATA ERROR CHECKING (START DATETIME ONLY):
  # This catches where the user only has a from/start date. This can occur when the event time is known.
  errors.missing.df <- plyr::count(is.na(df1[, 4]))
  errors.missing <- subset(errors.missing.df, x == TRUE)$freq
  
  if (length(errors.missing) > 0) {
    df1$duration[is.na(df1$datetime_to)] <- 1  
    # If TO datetime is missing, assign a duration of one minute (at the START datetime)
  } else {
    errors.missing <- 0
  }
  
  # DATA ERROR CHECKING (ILLOGICAL DATETIME SEQUENCE):
  #This catches when FROM date-times are later than the TO datetime. 
  errors.logic.df <- plyr::count(df1[, 5] < 0)
  errors.logic <- subset(errors.logic.df, x == TRUE)$freq
  
  if (length(errors.logic) > 0) {
    # At this point just noting the number. this leaves the duration as 
    # a negative number which the second part of the program understands. 
  } else {
    errors.logic <- 0
  }
  
  # DATA ERROR CHECKING (ROGUE ERRORS FROM POSIXt):
  #This catches errors from changes made to POSIXt in revision r82904 (2022-09-24 19:32:52). 
  errors.rogue.df <- plyr::count(is.na(df1[, 5]))
  errors.rogue <- subset(errors.rogue.df, x == TRUE)$freq
  
  if (length(errors.rogue) > 0) {
    # Fix the problem by adding a second to the start and end date times and recalculating duration
    df1$datetime_from[is.na(df1[, 5])] <- df1$datetime_from[is.na(df1[, 5])] + seconds(1)
    df1$datetime_to[is.na(df1[, 5])] <- df1$datetime_to[is.na(df1[, 5])] + seconds(1)
    suppressWarnings (df1$duration[is.na(df1[, 5])] <- as.duration(ymd_hms(df1$datetime_from[is.na(df1[, 5])]) %--% ymd_hms(df1$datetime_to[is.na(df1[, 5])])))
  } else {
    errors.rogue <- 0
  }
  
  # Finally, fix any stragglers that are still NA
  # DATA ERROR CHECKING (Stragglers):
  #This catches errors still lurking from above and marks as -1
  errors.unfixable.df <- plyr::count(is.na(df1[, 5]))
  errors.unfixable <- subset(errors.unfixable.df, x == TRUE)$freq
  
  if (length(errors.unfixable) > 0) {
    # Fix the problem by adding a second to the start and end date times and recalculating duration
    df1$duration[is.na(df1[, 5])] <- -1
  } else {
    errors.unfixable <- 0
  }
  
  
  # Create result df and loop through rows -----------------------------------
  
  # Create a new dataframe to hold aoristic value for each hour of the week. 
  df2 <- data.frame(matrix(0, ncol = 168, nrow = nrow(df1)))
  
  for (i in 1:168){  
    names(df2)[i] <- paste("hour", i, sep = "") 
  }
  df1 <- cbind(df1, df2)  # Bind the source data to the hours matrix
  rm(df2)                 # Tidy up data.frame
  
  
  # Loop each data row and allocate aoristic probability
  
  for (i in seq_len(nrow(df1))) {
    from.day <- wday(df1[i, "datetime_from"])               # The day number for the start date
    from.hour <- hour(df1[i, "datetime_from"])              # The hour number for the start hour
    time.span <- df1[i, "duration"]                         # The event time span
    hour.position <- ((24 * (from.day - 1)) + from.hour) + 1
    cur.column.name <- paste("hour", hour.position, sep = "")
    left.in.hour <- 60 - minute(df1[i, "datetime_from"])    # For when start hour begins > :00
    aor.minute <- 1 / time.span                             # Aoristic weight per minute
    
    # Catch the rare occurrence when there is no START date-time
    if (is.na(from.day)) {
      txt <- paste("Warning message: No START date-time found in row ", i, ". Row will be ignored.", sep = '')
      message(txt)
      next
    }
    
    if (time.span >= 10080) {                       
      # Event duration > one week. Increments each day/hour equally.
      for (j in 1:168) {
        cur.column.name <- paste("hour", j, sep = "")
        df1[i, cur.column.name] <- df1[i, cur.column.name] + 1 / 168
      }
    }
    
    
    if (is.na(df1[i, 'datetime_to'])) {
      # The End date is missing, in crime data often when the event time is precisely known. 
      # In these cases, aoristic.df assigns the time.span to the containing hour block (+1)
      df1[i, cur.column.name] <- df1[i, cur.column.name] + time.span 
    }   
    
    
    if (time.span >= 0 && time.span <= 1 && !is.na(df1[i, 'datetime_to'])) {
      # Event duration is known precisely, with duration 0 or 1 and the TO datetime
      # field exists. In these cases, aoristic.df assigns the containing hour block +1
      df1[i, cur.column.name] <- df1[i, cur.column.name] + 1
    }
    
    
    if (time.span < 0) {
      # Event time span is illogical in that End datetime is before Start datetime.
      # Some options here. Either -1-, ignore this row, or -2- use the Start datetime
      # and proceed as if the End datetime did not exist [as above].
      # next                                                  #1 (ignore)
      df1[i, cur.column.name] <- df1[i, cur.column.name] + 1  #2 (use start date)
      # A third future option is to swap start and end datetimes
    }
    
    
    if (time.span > 1 && time.span < 10080) {
      # We have an event with a time span that has to be distributed appropriately.
      # Assign aoristic weights until the remaining minutes in the time span are exhausted.
      rmg.mins <- time.span   
      
      while (rmg.mins > 0) {
        if (rmg.mins <= left.in.hour) {
          # then the current hour can be assigned the remaining aoristic weight
          df1[i, cur.column.name] <- df1[i, cur.column.name] + (rmg.mins * aor.minute)
          rmg.mins <- 0
        }
        if (rmg.mins > left.in.hour) {
          df1[i, cur.column.name] <- df1[i, cur.column.name] + (left.in.hour * aor.minute)
          rmg.mins <- rmg.mins - left.in.hour             # decrease rmg.mins
          left.in.hour <- 60                              # reset so the next time period is a full hour
          ifelse (hour.position >= 168, hour.position <- 1, hour.position <- hour.position + 1)
          cur.column.name <- paste("hour", hour.position, sep = "")
        }
      }
    }
  }  
  
  
  if (myMessages) {
    message("\nAoristic data frame created.")
    
    # Report how many rows only had a start datetime
    if (errors.missing > 0) {
      message(paste("  ", errors.missing, " row(s) were missing END/TO datetime values.", sep = ""))
    }
    # Report how many rows only start datetimes after end datetimes
    if (errors.logic > 0) {
      message(paste("  ", errors.logic, " row(s) had END/TO datetimes before START/FROM datetimes.", sep = ""))
    }
    # Report rogue errors (miscellaneous but fixed by the one second addition)
    if (errors.rogue > 0) {
      message(paste("  ", errors.rogue, " row(s) had miscellaneous errors that this package repaired.", sep = ""))
    }
    # Report unfixable errors (Nope, I've no idea why)
    if (errors.unfixable > 0) {
      message(paste("  ", errors.unfixable, " row(s) had undiagnosed errors that this package had to ignore.", "\n", sep = ""))
    }
    # Report rogue errors (miscellaneous wtfs)
    if (errors.rogue > 0) {
      message(paste("  ", errors.rogue, " row(s) had miscellaneous errors that this package repaired.", "\n", sep = ""))
    }
  }  
  
  return(df1)
}

