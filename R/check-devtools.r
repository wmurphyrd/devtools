#' Custom devtools release checks.
#'
#' This function performs additional checks prior to release. It is called
#' automatically by \code{\link{release}()}.
#'
#' @param pkg package description, can be path or package name.  See
#'   \code{\link{as.package}} for more information.
#' @keywords internal
#' @export
release_checks <- function(pkg = ".", built_path = NULL) {
  pkg <- as.package(pkg)
  message("Running additional devtools checks for ", pkg$package)

  check_version(pkg)
  check_dev_versions(pkg)
  check_vignette_titles(pkg)
  check_news_md(pkg)
  check_remotes(pkg)
  check_doc_files(pkg)
}

check_dev_versions <- function(pkg = ".") {
  pkg <- as.package(pkg)

  dep_list <- pkg[tolower(standardise_dep(TRUE))]
  deps <- do.call("rbind", unname(compact(lapply(dep_list, parse_deps))))
  deps <- deps[!is.na(deps$version), , drop = FALSE]

  parsed <- lapply(deps$version, function(x) unlist(numeric_version(x)))

  lengths <- vapply(parsed, length, integer(1))
  last_ver <- vapply(parsed, function(x) x[[length(x)]], integer(1))

  is_dev <- lengths == 4 & last_ver >= 9000

  check_status(
    !any(is_dev),
    "dependencies don't rely on dev versions",
    paste(
      "depends on devel versions of: ",
      paste0(deps$name[is_dev], collapse = ", ")
    )
  )

  return(invisible(FALSE))
}

check_version <- function(pkg = ".") {
  pkg <- as.package(pkg)
  ver <- unlist(numeric_version(pkg$version))

  check_status(length(ver) == 3,
    "version number has three components",
    paste0("version (", pkg$version, ") should have exactly three components")
  )
}

check_vignette_titles <- function(pkg = ".") {
  pkg <- as.package(pkg)
  vigns <- tools::pkgVignettes(dir = pkg$path)
  if (length(vigns$docs) == 0) return()

  has_vignette_title <- function(v, n) {
    h <- readLines(v, n = n)
    any(grepl("Vignette Title", h))
  }
  v <- stats::setNames(vigns$docs, basename(vigns$docs))
  has_vt <- vapply(v, has_vignette_title, logical(1), n = 30)

  check_status(
    !any(has_vt),
    "vignette titles are not placeholders",
    paste0(
      "placeholder 'Vignette Title' detected in 'title' field and/or ",
      "'VignetteIndexEntry' for: ",
      paste(names(has_vt)[has_vt], collapse = ",")
    )
  )
}

check_news_md <- function(pkg) {
  pkg <- as.package(pkg)

  news_path <- file.path(pkg$path, "NEWS.md")
  if (!file.exists(news_path))
    return()

  ignore_path <- file.path(pkg$path, ".Rbuildignore")
  if (!file.exists(ignore_path)) {
    ignore_lines <- character()
  } else {
    ignore_lines <- readLines(ignore_path)
  }

  has_news <- grepl("NEWS\\.md", ignore_lines, fixed = TRUE) |
              grepl("NEWS.md", ignore_lines, fixed = TRUE)

  check_status(!any(has_news),
    "NEWS.md is not ignored",
    "NEWS.md now supported by CRAN and doesn't need to be ignored."
  )

  news_rd_path <- file.path(pkg$path, "inst/NEWS.Rd")
  check_status(
    !file.exists(news_rd_path),
    "NEWS.Rd does not exist",
    "NEWS.md now supported by CRAN, NEWS.Rd can be removed."
  )
}

check_remotes <- function(pkg) {
  check_status(!has_dev_remotes(pkg),
    "DESCRIPTION doesn't have Remotes field",
    "Remotes field should be removed before CRAN submission."
  )
}

check_status <- function(status, name, warning) {
  cat("Checking ", name, "...", sep = "")

  status <- tryCatch(
    if (status) {
      cat(" OK\n")
    } else {
      cat("\n")
      message("WARNING: ", warning)
    },
    error = function(e) {
      cat("\n")
      message("ERROR: ", conditionMessage(e))
      FALSE
    }
  )

  invisible(status)
}

check_doc_files <- function(pkg) {
  pkg <- as.package(pkg)
  doc_path <- file.path(pkg$path, "inst", "doc")

  check_status(length(dir(doc_path)) == 0,
               "/inst/doc does not contain errant files",
               "Vignette testing files should be removed with clean_vignettes"
  )
}
