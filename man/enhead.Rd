% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/enhead.R
\name{enhead}
\alias{enhead}
\title{Join data cells to headers}
\usage{
enhead(data_cells, header_cells, direction, drop = TRUE)
}
\arguments{
\item{data_cells}{Data frame of data cells with at least the columns 'row'
and 'column', which are \code{numeric} or \code{integer}.}

\item{header_cells}{Data frame of header cells with at least the columns
'row' and 'column', which are numeric/integer vectors.}

\item{direction}{The direction between a data cell and its header, one of
\code{"N"}, \code{"E"}, \code{"S"}, \code{"W"}, \code{"NNW"}, \code{"NNE"}, \code{"ENE"}, \code{"ESE"}, \code{"SSE"},
\code{"SSW"}. \code{"WSW"}, \code{"WNW"}, \code{"ABOVE"}, \code{"BELOW"}, \code{"LEFT"} and \code{"RIGHT"}.  See
'details'.}

\item{drop}{Logical vector length 1. Whether data cells that can't be
associated with a header should be dropped.  Default: \code{TRUE}.}
}
\description{
Data cells in a table are associated with header cells by proximity.
\code{\link[=enhead]{enhead()}} joins a data frame of data cells to a data frame of header cells,
choosing the nearest header cells in the given direction.
}
\details{
Headers are associated with data by proximity in a given direction.  The
directions are mapped to the points of the compass, where 'N' is north (up),
'E' is east (right), and so on.  \code{\link[=enhead]{enhead()}} finds the nearest header to
a given data cell in a given direction, and joins it to the data cell.

The most common directions to search are \code{"NNW"} (for left-aligned headers at
the top of the table) and \code{"WNW"} for top-aligned headers at the side of the
table.

The full list of available directions is \code{"N"}, \code{"E"}, \code{"S"}, \code{"W"}, \code{"NNW"},
\code{"NNE"}, \code{"ENE"}, \code{"ESE"}, \code{"SSE"}, \code{"SSW"}, \code{"WSW"}, \code{"WNW"}, \code{"ABOVE"},
\code{"BELOW"}, \code{"LEFT"}, \code{"RIGHT"}.  For convenience, these directions are
provided as their own functions, wrapping the concept of \code{\link[=enhead]{enhead()}}.

The difference between \code{"N"} and \code{"ABOVE"} (and similar pairs of directions)
is that \code{"N"} finds headers directly above the data cell, whereas \code{"ABOVE"}
matches the nearest header, whether above-left, above-right or directly above
the data cell.  This is useful for matching headers that are not aligned to
the edge of the data cells that they refer to.  There can be a tie in the
directions \code{"ABOVE"}, \code{"BELOW"}, \code{"LEFT"} and \code{"RIGHT"} , causing \code{NA}s to be
returned in the place of header values.  Avoid ties by using \code{\link[=justify]{justify()}}
first to align header cells to the corner of the data cells they describe.
}
\examples{
library(dplyr)
# Load some pivoted data
(x <- purpose$`NNW WNW`)
# Make a tidy representation
cells <- as_cells(x)
cells <- cells[!is.na(cells$chr), ]
head(cells)
# Select the cells containing the values
data_cells <-
  filter(cells, row >= 3, col >= 3) \%>\%
  transmute(row, col, count = as.integer(chr))
head(data_cells)
# Select the headers
qualification <-
  filter(cells, col == 1) \%>\%
  select(row, col, qualification = chr)
age <-
  filter(cells, col == 2) \%>\%
  select(row, col, age = chr)
gender <-
  filter(cells, row == 1) \%>\%
  select(row, col, gender = chr)
satisfaction <-
  filter(cells, row == 2) \%>\%
  select(row, col, satisfaction = chr)
# From each data cell, search for the nearest one of each of the headers
data_cells \%>\%
  enhead(gender, "NNW") \%>\%
  enhead(satisfaction, "N") \%>\%
  enhead(qualification, "WNW") \%>\%
  enhead(age, "W") \%>\%
  select(-row, -col)

# The `drop` argument controls what happens when for some cells there is no
# header in the given direction. When `drop = TRUE` (the default), cells that
# can't be joined to a header are dropped.  Otherwise they are kept.
enhead(data_cells, gender, "N")
enhead(data_cells, gender, "N", drop = FALSE)
}
