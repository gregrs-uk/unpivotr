#' Strip a level of headers from a pivot table
#'
#' @description [behead()] takes one level of headers from a pivot table and
#' makes it part of the data.  Think of it like [tidyr::gather()], except that
#' it works when there is more than one row of headers (or more than one column
#' of row-headers), and it only works on tables that have first come through
#' [as_cells()] or [tidyxl::xlsx_cells()].
#'
#' @param cells Data frame. The cells of a pivot table, usually the output of
#'   [as_cells()] or [tidyxl::xlsx_cells()], or of a subsequent operation on
#'   those outputs.
#' @param direction The direction between a data cell and its header, one of
#' `"N"`, `"E"`, `"S"`, `"W"`, `"NNW"`, `"NNE"`, `"ENE"`, `"ESE"`, `"SSE"`,
#' `"SSW"`. `"WSW"` and `"WNW"`.  See 'details'.  `"ABOVE"`, `"BELOW"`, `"LEFT"`
#' and `"RIGHT"` aren't available because they require certain ambiguities that
#' are better handled by using [enhead()] directly rather than via [behead()].
#' @param name A name to give the new column that will be created, e.g.
#'   `"location"` if the headers are locations.  Quoted (`"location"`, not
#'   `location`) because it doesn't refer to an actual object.
#' @param values Optional. The column of `cells` to use as the values of each
#'   header.  Given as a bare variable name.  If omitted (the default), the
#'   `types` argument will be used instead.
#' @param types The name of the column that names the data type of each cell.
#'   Usually called `data_types` (the default), this is a character column that
#'   names the other columns in `cells` that contain the values of each cell.
#'   E.g.  a cell with a character value will have `"character"` in this column.
#'   Unquoted(`data_types`, not `"data_types"`) because it refers to an actual
#'   object.
#' @param formatters A named list of functions for formatting each data type in
#'   a set of headers of mixed data types, e.g. when some headers are dates and
#'   others are characters.  These can be given as `character = toupper` or
#'   `character = ~ toupper(.x)`, similar to [purrr::map].
#' @param drop_na logical Whether to filter out headers that have `NA` in the
#'   `value` column.  Default: `TRUE`.  This can happen with the output of
#'   `tidyxl::xlsx_cells()`, when an empty cell exists because it has formatting
#'   applied to it, but should be ignored.
#'
#' @return A data frame
#'
#' @export
#' @examples
#' # A simple table with a row of headers
#' (x <- data.frame(a = 1:2, b = 3:4))
#'
#' # Make a tidy representation of each cell
#' (cells <- as_cells(x, col_names = TRUE))
#'
#' # Strip the cells in row 1 (the original headers) and use them as data
#' behead(cells, "N", foo)
#'
#' # More complex example: pivot table with several layers of headers
#' (x <- purpose$`NNW WNW`)
#'
#' # Make a tidy representation
#' cells <- as_cells(x)
#' head(cells)
#' tail(cells)
#'
#' # Strip the headers and make them into data
#' tidy <-
#'   cells %>%
#'   behead("NNW", Sex) %>%
#'   behead("N", `Sense of purpose`) %>%
#'   behead("WNW", `Highest qualification`) %>%
#'   behead("W", `Age group (Life-stages)`) %>%
#'   dplyr::mutate(count = as.integer(chr)) %>%
#'   dplyr::select(-row, -col, -data_type, -chr)
#' head(tidy)
#'
#' # Check against the provided 'tidy' version of the data.
#' dplyr::anti_join(tidy, purpose$Tidy)
#'
#' # The provided 'tidy' data is missing a row for Male 15-24-year-olds with a
#' # postgraduate qualification and a sense of purpose between 0 and 6.  That
#' # seems to have been an oversight by Statistics New Zealand.
behead <- function(cells, direction, name, values = NULL, types = data_type,
                   formatters = list(), drop_na = TRUE) {
  UseMethod("behead")
}

#' @export
behead.data.frame <- function(cells, direction, name, values = NULL,
                              types = data_type, formatters = list(),
                              drop_na = TRUE) {
  check_direction_behead(direction)
  check_distinct(cells)
  name <- rlang::ensym(name)
  functions <- purrr::map(formatters, purrr::as_mapper)
  values <- rlang::enexpr(values)
  if(is.null(values)) {
    values_was_null <- TRUE
    types <- rlang::ensym(types)
  } else {
    values_was_null <- FALSE
    values <- rlang::ensym(values)
    types <- rlang::sym(".data_type")
    cells <-
      cells %>%
      dplyr::mutate(.value = !! values) %>%
      dplyr::mutate(!! types := ".value")
  }
  type_names <- unique(dplyr::pull(cells, !! types))
  filter_expr <- direction_filter(direction)
  is_header <- rlang::eval_tidy(filter_expr, cells)
  headers <-
    cells %>%
    dplyr::filter(is_header) %>%
    pack(types = !! types) %>%
    dplyr::mutate(is_na = is.na(value),
                  !! name := purrr::imap(value,
                                         maybe_format_list_element,
                                         functions),
                  !! name := concatenate(!! name)) %>%
    dplyr::filter(!(drop_na & is_na)) %>%
    dplyr::select(row, col, !! name)
  data_cells <- dplyr::filter(cells, !is_header)
  out <- enhead(data_cells, headers, direction, drop = FALSE)
  if(!values_was_null) out <- dplyr::select(out, -.value, -.data_type)
  out
}

# Construct a filter expression for stripping a header from a pivot table
direction_filter <- function(direction) {
  direction <- substr(direction, 1L, 1L)
  dplyr::case_when(direction == "N" ~ rlang::expr(.data$row == min(.data$row)),
                   direction == "E" ~ rlang::expr(.data$col == max(.data$col)),
                   direction == "S" ~ rlang::expr(.data$row == max(.data$row)),
                   direction == "W" ~ rlang::expr(.data$col == min(.data$col)))
}

# Check that a given direction is a supported compass direction
check_direction_behead <- function(direction_string) {
  directions <- c("NNW", "N", "NNE",
                  "ENE", "E", "ESE",
                  "SSE", "S", "SSW",
                  "WSW", "W", "WNW")
  other_directions <- c("ABOVE", "LEFT", "RIGHT", "BELOW")
  if (direction_string %in% other_directions) {
    stop("`direction` must be one of \"",
         paste(directions, collapse = "\", \""),
         "\".  To use the directions \"",
         paste(other_directions, collapse = "\", \""),
         "\" look at `?enhead`.")
  }
  if (!(direction_string %in% directions)) {
    stop("`direction` must be one of \"",
         paste(directions, collapse = "\", \""),
         "\"")
  }
}
