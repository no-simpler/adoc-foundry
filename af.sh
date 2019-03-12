#!/usr/bin/env bash

## Driver function
main()
{
  __initialize_this
  __declare_global_colors

  parse_arguments "$@"
  declare_globals

  entry_check
  process_files
}

parse_arguments()
{
  # Main mode of operation (html|pdf|prince)
  MODE_BACKEND='html'

  # Whether to make child commands verbose
  MODE_VERBOSE=false

  # Whether to clear tmp and out directories before processing
  MODE_CLEAR=false

  # Whether overrides for asciidoctor from $ATTR_DIRNAME will be considered
  MODE_OVERRIDING_ATTR=false

  # Whether overrides for asciidoctor from $STYLE_DIRNAME will be considered
  MODE_OVERRIDING_STYLE=false

  # Whether a list of .adoc files has been provided by the user
  MODE_FILES_PROVIDED=false

  # Whether math output will use SVG rendering or HTML+CSS
  MODE_SVG=true

  # List of .adoc files to process, initially filled from cli arguments
  FILE_LIST=()

  # List of 
  CLI_OPTS=()

  local arg cli_attribute_expected=false cli_require_expected=false
  for arg in "$@"; do
    if $cli_attribute_expected; then
      CLI_OPTS+=("--attribute=$arg")
      cli_attribute_expected=false
      continue
    elif $cli_require_expected; then
      CLI_OPTS+=("--require=$arg")
      cli_attribute_expected=false
      continue
    elif [[ $arg =~ ^(-a.+|--attribute=.+)$ ]]; then
      CLI_OPTS+=("$arg")
      continue
    elif [[ $arg =~ ^(-r.+|--require=.+)$ ]]; then
      CLI_OPTS+=("$arg")
      continue
    elif [[ $arg =~ ^(-a|--attribute)$ ]]; then
      cli_attribute_expected=true
      continue
    elif [[ $arg =~ ^(-r|--require)$ ]]; then
      cli_require_expected=true
      continue
    elif [[ $arg =~ ^(-h|--html)$ ]]; then
      MODE_BACKEND='html'
      continue
    elif [[ $arg =~ ^(-p|--pdf)$ ]]; then
      MODE_BACKEND='pdf'
      continue
    elif [[ $arg =~ ^(-P|--prince-pdf)$ ]]; then
      MODE_BACKEND='prince'
      continue
    elif [[ $arg =~ ^(-v|--verbose)$ ]]; then
      MODE_VERBOSE=true
      continue
    elif [[ $arg =~ ^(-c|--clear-out)$ ]]; then
      MODE_CLEAR=true
      continue
    elif [[ $arg =~ ^(-A|--override-attr)$ ]]; then
      MODE_OVERRIDING_ATTR=true
      continue
    elif [[ $arg =~ ^(-S|--override-style)$ ]]; then
      MODE_OVERRIDING_STYLE=true
      continue
    elif [[ $arg =~ ^(-B|--override-both)$ ]]; then
      MODE_OVERRIDING_ATTR=true
      MODE_OVERRIDING_STYLE=true
      continue
    elif [[ $arg =~ ^(-g|--svg)$ ]]; then
      MODE_SVG=true
      continue
    elif [[ $arg =~ ^(-G|--no-svg)$ ]]; then
      MODE_SVG=false
      continue
    elif [[ $arg =~ ^(-[a-zA-Z0-9]+)$ ]]; then
      local i letter
      for i in $( seq 2 ${#arg} ); do
        letter="${arg:i-1:1}"
        case $letter in
          h)  MODE_BACKEND='html';;
          p)  MODE_BACKEND='pdf';;
          P)  MODE_BACKEND='prince';;
          v)  MODE_VERBOSE=true;;
          c)  MODE_CLEAR=true;;
          A)  MODE_OVERRIDING_ATTR=true;;
          S)  MODE_OVERRIDING_STYLE=true;;
          B)  MODE_OVERRIDING_ATTR=true
              MODE_OVERRIDING_STYLE=true
              ;;
          g)  MODE_SVG=true;;
          G)  MODE_SVG=false;;
          *) :;;
        esac
      done
      continue
    fi
    FILE_LIST+=("$arg")
    MODE_FILES_PROVIDED=true
  done

  return 0
}

declare_globals()
{
  ATTR_FILENAME_SUFFIX='txt'
  case $MODE_BACKEND in
    pdf)
      STYLE_FILENAME_SUFFIX='yml'
      ;;
    prince)
      STYLE_FILENAME_SUFFIX='css'
      ;;
    *)
      STYLE_FILENAME_SUFFIX='css'
      ;;
  esac
  PRINCE_STYLE_FILENAME_SUFFIX='css'

  # Names of files and directories
  SRC_DIRNAME='src'
  TMP_DIRNAME='tmp'
  OUT_DIRNAME='out'
  CONFIG_DIRNAME='config'
  ATTR_DIRNAME="$CONFIG_DIRNAME/asciidoctor/attr/$MODE_BACKEND"
  STYLE_DIRNAME="$CONFIG_DIRNAME/asciidoctor/style/$MODE_BACKEND"
  
  PHANTOMJS_SCRIPT_DIRNAME="$CONFIG_DIRNAME/phantomjs"
  MATHJAX_SCRIPT_DIRNAME="$CONFIG_DIRNAME/mathjax"
  PRINCE_STYLE_DIRNAME="$CONFIG_DIRNAME/prince"

  SHARED_ATTR_FILENAME="default.$ATTR_FILENAME_SUFFIX"
  SHARED_STYLE_FILENAME="default.$STYLE_FILENAME_SUFFIX"
  SHARED_PRINCE_STYLE_FILENAME="default.$PRINCE_STYLE_FILENAME_SUFFIX"

  PHANTOMJS_SCRIPT_FILENAME='render-math.js'
  if $MODE_SVG; then
    MATHJAX_SCRIPT_FILENAME='with-svg.js'
  else
    MATHJAX_SCRIPT_FILENAME='with-html.js'
  fi

  # Absolute paths to files and directories above
  SRC_DIRPATH="$THIS_DIR/$SRC_DIRNAME"
  TMP_DIRPATH="$THIS_DIR/$TMP_DIRNAME"
  OUT_DIRPATH="$THIS_DIR/$OUT_DIRNAME"
  ATTR_DIRPATH="$THIS_DIR/$ATTR_DIRNAME"
  STYLE_DIRPATH="$THIS_DIR/$STYLE_DIRNAME"

  PRINCE_STYLE_DIRPATH="$THIS_DIR/$PRINCE_STYLE_DIRNAME"

  SHARED_ATTR_FILEPATH="$ATTR_DIRPATH/$SHARED_ATTR_FILENAME"
  SHARED_STYLE_FILEPATH="$STYLE_DIRPATH/$SHARED_STYLE_FILENAME"
  SHARED_PRINCE_STYLE_FILEPATH="$PRINCE_STYLE_DIRPATH/$SHARED_PRINCE_STYLE_FILENAME"

  PHANTOMJS_SCRIPT_FILEPATH="$THIS_DIR/$PHANTOMJS_SCRIPT_DIRNAME/$PHANTOMJS_SCRIPT_FILENAME"
  MATHJAX_SCRIPT_FILEPATH="$THIS_DIR/$MATHJAX_SCRIPT_DIRNAME/$MATHJAX_SCRIPT_FILENAME"

  # Base options to be passed to asciidoctor
  BASE_OPTS=()

  $MODE_VERBOSE && BASE_OPTS+=('--verbose')

  if [[ $MODE_BACKEND =~ ^(html|prince)$ ]]; then
    # Asciidoctor will produce html, as a final or temp product respectively
    BASE_OPTS+=('--backend=html5')
  elif [[ $MODE_BACKEND =~ ^pdf$ ]]; then
    # Asciidoctor will produce pdf, using asciidoctor-pdf
    BASE_OPTS+=('--backend=pdf')
    BASE_OPTS+=('--require=asciidoctor-pdf')
  
    ## Normally, asciidoctor-mathematical is required for asciidoctor-pdf, to 
    #+ process math. It is unfortunately unreliable. For documents containing 
    #+ math, the alternative workflow via Prince is recommended.
    #.
    # BASE_OPTS+=("--require asciidoctor-mathematical")
  fi

  # Container for shared attribute overrides coming from $SHARED_ATTR_FILENAME
  SHARED_OPTS=()

  return 0
}

entry_check()
{
  # Too flashy, disabled
  # __print_colored_plaque \
  #   $WHITE \
  #   62 \
  #   'adoc-foundry'
  # printf '\n'

  if ! asciidoctor -v &>/dev/null; then
    __print_warning 'Asciidoctor is not found. Aborting.'
    exit 1
  fi

  local mode
  mode="Mode '$MODE_BACKEND'"

  local files
  $MODE_FILES_PROVIDED \
    && files='User-provided files' \
    || files="Files in '$SRC_DIRNAME'"

  local overrides
  if $MODE_OVERRIDING_ATTR; then
    if $MODE_OVERRIDING_STYLE; then
      overrides='Overriding AD attr and style'
    else
      overrides='Overriding AD attr'
    fi
  else
    if $MODE_OVERRIDING_STYLE; then
      overrides='Overriding AD style'
    else
      overrides='No AD overrides'
    fi
  fi

  local modes=()
  if $MODE_CLEAR; then
    [ "$MODE_BACKEND" = 'prince' ] \
      && modes+=("pre-clearing '$OUT_DIRNAME' and '$TMP_DIRNAME'") \
      || modes+=("pre-clearing '$OUT_DIRNAME'")
  fi
  $MODE_VERBOSE && modes+=('being verbose')
  modes=$( printf '; %s' "${modes[@]}" )
  modes=${modes:2}
  [ -n "$modes" ] && modes="(Also: $modes)"

  __print_colored_msg \
    $WHITE \
    "$mode" \
    "$files" \
    "$overrides" \
    "$modes"

  # These are superceded by the output above
  # if ! $MODE_OVERRIDING_ATTR; then
  #   if ! $MODE_OVERRIDING_STYLE; then
  #     __print_ignoring '' "$CONFIG_DIRNAME directory altogether"
  #   else
  #     __print_ignoring '' "$ATTR_DIRNAME directory"
  #   fi
  # else
  #   if ! $MODE_OVERRIDING_STYLE; then
  #     __print_ignoring '' "$STYLE_DIRNAME directory"
  #   fi
  # fi

  if [ ${#CLI_OPTS[@]} -gt 0 ]; then
    printf 'Recognized asciidoctor overrides:\n'
    local override
    for override in "${CLI_OPTS[@]}"; do
      printf '%s\n' "$override"
    done
  fi

  printf '\n'

  return 0
}

attr_to_opt()
{
  local line="$*"
  line="$( __decomment "$line" )"
  [[ ! $line =~ ^:.+:.*$ ]] && { printf '\n'; return 1; }

  local attr val opt=''
  attr="$( cut -d ':' -f 2 <<< "$line" )"
  attr="$( __trim "$attr" )"
  if [ -n "$attr" ]; then
    opt="--attribute=$attr"
    val="$( cut -d ':' -f 3- <<< "$line" )"
    val="$( __trim "$val" )"
    [ -n "$val" ] && opt="$opt=$val"
  fi

  printf '%s\n' "$opt"
  return 0
}

## process_files()
#.
## 1. Take the list of .adoc files passed by user
#+ 2. Absent that, scan src directory for .adoc files
#+ 3. For each .adoc file:
#+ 3.1. Attribute-wise, do the first applicable:
#+ 3.1.1. If ‘-oa’ is passed, take the attribute file from config directory with
#+        the same name, but with .txt suffix instead of .adoc.
#+ 3.1.2. If ‘-oa’ is passed, take ‘default.txt’ from config directory.
#+ 3.1.3. Don’t use attribute overrides from config directory.
#+ 3.2. Stylesheet-wise, do the first applicable:
#+ 3.2.1. If ‘-os’ is passed, take the stylesheet from config directory with 
#+        the same name, but with .css suffix instead of .adoc.
#+ 3.2.2. If ‘-os’ is passed, take ‘default.css’ from config directory.
#+ 3.2.3. Use asciidoctor’s built-in stylesheet.
#+ 3.3. Apply any attribute overrides passed to this script with ‘-a’.
#+ 3.4. Process the file and put final output onto out directory.
#.
## Arguments:
#+ $@                     - (optional) (anywhere)
#+                          List of specific files to process. Without it, just 
#+                          scans src directory for .adoc files.
#+ '-oa|--override-attr'  — (optional) (anywhere)
#+                          Enable attribute overrides from config directory.
#+ '-os|--override-style' — (optional) (anywhere)
#+                          Enable custom stylesheets from config directory.
#+ '-o|--override-all'    — (optional) (anywhere)
#+                          Equivalent of both ‘-oa’ and ‘-os’
#+ '-a ATTR[=VALUE]'      - (optional) (anywhere) 
#+                          Override asciidoctor attributes.
#.
## Returns:
#+ 1  — If no ‘asciidoctor’ executable is found on the $PATH
#+ 0  — In all other cases
#.
## Provides into the global scope:
#+ _nothing_
#.
## Prints:
#+ Human-readable progress messages
process_files()
{
  if [ -r "$SHARED_ATTR_FILEPATH" ]; then
    local line
    while IFS='' read -r -u 10 line; do
      line="$( attr_to_opt "$line" )"
      [ -n "$line" ] && SHARED_OPTS+=("$line")
    done 10< "$SHARED_ATTR_FILEPATH"
  fi

  if ! $MODE_FILES_PROVIDED; then
    FILE_LIST=( "$SRC_DIRPATH/"*.adoc )
  fi

  if $MODE_CLEAR; then
    rm -rf "$OUT_DIRPATH"/*
    if [ $MODE_BACKEND = 'prince' ]; then
      rm -rf "$TMP_DIRPATH"/*
    fi
  fi

  local  adoc_filename  adoc_filepath
  local   out_filename   out_filepath
  local   tmp_filename   tmp_filepath
  local  math_filename  math_filepath
  local  attr_filename  attr_filepath
  local style_filename style_filepath

  local prince_style_filename prince_style_filepath

  local using_style using_prince_style
  local opts

  for adoc_filepath in "${FILE_LIST[@]}"; do

    adoc_filename="${adoc_filepath##*/}"

    case $adoc_filename in *.adoc) :;; *) {
      __print_warning '' "Not .adoc file: '$adoc_filename'"
      continue
    };; esac

    if [ ! -r "$adoc_filepath" ]; then
      __print_warning '' "Unable to read file: '$adoc_filename'"
      continue
    fi

    # Base options, essential to the $MODE_BACKEND
    opts=("${BASE_OPTS[@]}")

    # Options for output
    case $MODE_BACKEND in
      pdf)
        out_filename="${adoc_filename%.adoc}.pdf"
        out_filepath="$OUT_DIRPATH/$out_filename"
        opts+=("--out-file=$out_filepath")
        ;;
      prince)
        tmp_filename="${adoc_filename%.adoc}.prince.html"
        tmp_filepath="$TMP_DIRPATH/$tmp_filename"
        opts+=("--out-file=$tmp_filepath")
        math_filename="${adoc_filename%.adoc}.prince-with-math.html"
        math_filepath="$TMP_DIRPATH/$math_filename"
        out_filename="${adoc_filename%.adoc}.pdf"
        out_filepath="$OUT_DIRPATH/$out_filename"
        ;;
      *)
        out_filename="${adoc_filename%.adoc}.html"
        out_filepath="$OUT_DIRPATH/$out_filename"
        opts+=("--out-file=$out_filepath")
        ;;
    esac

    # Options for custom stylesheets (when $MODE_OVERRIDING_STYLE is enabled)
    using_style=false
    if $MODE_OVERRIDING_STYLE; then
      style_filename="${adoc_filename%.adoc}.$STYLE_FILENAME_SUFFIX"
      style_filepath="$STYLE_DIRPATH/$style_filename"
      
      if [ -r "$style_filepath" ]; then
        using_style=true
      else
        if [ -r "$SHARED_STYLE_FILEPATH" ]; then
          style_filename="$SHARED_STYLE_FILENAME"
          style_filepath="$SHARED_STYLE_FILEPATH"
          using_style=true
        fi
      fi
    fi
    if $using_style; then
      case $MODE_BACKEND in
        pdf)
          opts+=("--attribute=pdf-style=$style_filepath")
          ;;
        prince)
          opts+=("--attribute=stylesheet=$style_filepath")
          ;;
        *)
          opts+=("--attribute=stylesheet=$style_filepath")
          ;;
      esac
    fi

    # Options for overriding attributes (when $MODE_OVERRIDING_ATTR is enabled)
    if $MODE_OVERRIDING_ATTR; then
      attr_filename="${adoc_filename%.adoc}.$ATTR_FILENAME_SUFFIX"
      attr_filepath="$ATTR_DIRPATH/$attr_filename"

      if [ -r "$attr_filepath" ]; then
        local line
        while IFS='' read -r -u 10 line; do
          line="$( attr_to_opt "$line" )"
          [-n "$line" ] && opts+=("$line")
        done 10< "$attr_filepath"
      else
        opts+=("${SHARED_OPTS[@]}")
      fi
    fi

    # Options passed via CLI
    opts+=("${CLI_OPTS[@]}")

    # Report status
    if $using_style; then
      __print_processing \
        "$adoc_filename" \
        "using $STYLE_DIRNAME/$style_filename"
    else
      __print_processing \
        "$adoc_filename" \
        'using asciidoctor’s built-it stylesheet'
    fi

    # Run asciidoctor
    asciidoctor \
      "${opts[@]}" \
      -- "$adoc_filepath"

    # Run Prince, if necessary
    if [ "$MODE_BACKEND" = 'prince' ]; then
      # Resolve stylesheet for Prince
      using_prince_style=false
      prince_style_filename="${adoc_filename%.adoc}.$PRINCE_STYLE_FILENAME_SUFFIX"
      prince_style_filepath="$PRINCE_STYLE_DIRPATH/$prince_style_filename"
      if [ -r "$style_filepath" ]; then
        using_prince_style=true
      else
        if [ -r "$SHARED_PRINCE_STYLE_FILEPATH" ]; then
          prince_style_filename="$SHARED_PRINCE_STYLE_FILENAME"
          prince_style_filepath="$SHARED_PRINCE_STYLE_FILEPATH"
          using_prince_style=true
        fi
      fi

      # Build CLI options
      opts=()
      $using_prince_style && opts+=("--style=$prince_style_filepath")
      opts+=('--javascript')
      
      # Prince is too verbose, and outputs essential errors anyway
      # $MODE_VERBOSE && opts+=("--verbose")

      # This should be put into config/prince/*.css
      # opts+=('--input=html')
      # opts+=('--page-size=A4')
      # opts+=('--media=print')

      # Make announcement
      if $using_prince_style; then
        __print_colored_msg \
          $YELLOW \
          '+++' \
          'Post-processing' \
          "$tmp_filename" \
          "using $PRINCE_STYLE_DIRNAME/$prince_style_filename"
      else
        __print_colored_msg \
          $YELLOW \
          '+++' \
          'Post-processing' \
          "$tmp_filename" \
          "using Prince’s built-in stylesheet"
      fi

      # Process math if there is a MathJax import
      if grep -q '^<script.*MathJax\.js' "$tmp_filepath"; then

        # Remove script tags that import MathJax
        if sed -i '//d' $( mktemp ) &>/dev/null; then
          sed -i \
            '/^<script.*MathJax\.js/d' \
            "$tmp_filepath"
        else
          sed -i '' \
            '/^<script.*MathJax\.js/d' \
            "$tmp_filepath"
        fi
            
        # Run phantomjs to process math
        cd "$THIS_DIR"
        phantomjs "$PHANTOMJS_SCRIPT_FILEPATH" \
          "$MATHJAX_SCRIPT_FILEPATH" \
          "$tmp_filepath" > "$math_filepath"
        
        # Rewiring the tmp path
        tmp_filepath="$math_filepath"

      fi

      # Run Prince
      prince \
        "${opts[@]}" \
        "$tmp_filepath" \
        -o "$out_filepath"
    fi

  done

  __print_done '' 'All files processed'
  return 0
}

## Boilerplate initialization for any top-level script that wishes to know its 
#. own precise location. This function should be called ASAP, specifically 
#. before the working directory of the script is changed by any means.
#.
## Designed to be run by bash >=3.2
#.
## Provides into the global scope:
#.
## $THIS_DIR  - read-only var containing absolute path to the directory that
#.              contains current script, with all symlinks resolved
#.
## __source_optional - command that sources scripts given their paths relative to 
#.                  the directory containing current script; returns non-zero 
#.                  if any single sourcing have failed
#.
## __source_required  - similar to previous, but calls ‘exit 1’ if any 
#.                          single sourcing have failed
__initialize_this()
{
  # (possibly relative) path to this script and a temp var
  local path="$BASH_SOURCE" abs_dir
  # resolve all symlinks
  while [ -L "$path" ]; do
    abs_dir="$( cd -P "$( dirname "$path" )" &> /dev/null && pwd )"
    path="$( readlink "$path" )"
    [[ $path != /* ]] && path="$abs_dir/$path"
  done
  # set global variable with this script’s dir
  readonly THIS_DIR="$( cd -P "$( dirname "$path" )" &> /dev/null && pwd )"
  # global helper for sourcing scripts in $THIS_DIR
  __source_optional() {
    local verbose=0; [[ $1 =~ ^(-v|--verbose)$ ]] && { verbose=1; shift;}
    local rel_path abs_path status=0
    for rel_path in "$@"; do
      abs_path="$THIS_DIR/$rel_path"
      if [ -f "$abs_path" -a -r "$abs_path" ]; then
        source "$abs_path" || status=1
      else 
        status=1; [[ $verbose = 1 ]] \
          && printf "Missing/unreadable script file at '%s'\n" "$abs_path"
      fi
    done
    return $status
  }
  # same as previous, but calls ‘exit 1’ if any failure have occured
  __source_required(){ __source_optional -v "$@" || exit 1;}
}

## __trim()
#.
## 1. Concatenate all args into a single string.
#+ 2. Remove both leading and trailing spaces.
#+ 3. Print the result.
#.
## Arguments:
#+ $* - String to trim
#.
## Returns:
#+ 0  — Always
#.
## Provides into the global scope:
#+ _nothing_
#.
## Prints:
#+ Trimmed input
__trim()
{
  printf '%s\n' "$*" \
    | sed \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//'
}

## __decomment()
#.
## 1. Concatenate all args into a single string.
#+ 2. Remove everything betwen the first occurrence of hash (‘#’) or 
#+    double-slash (‘//’) and the end of the string.
#+ 3. Remove both leading and trailing spaces.
#+ 4. Print the result.
#.
## Arguments:
#+ $* - String to decomment
#.
## Returns:
#+ 0  — Always
#.
## Provides into the global scope:
#+ _nothing_
#.
## Prints:
#+ Decommented, trimmed input
__decomment()
{
  printf '%s\n' "$*" \
    | sed \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*\([#].*\)\{0,1\}$//' \
    -e 's/[[:space:]]*\(\/\/.*\)\{0,1\}$//'
  return 0
}

## __declare_global_colors()
#.
## Pours into the global scope a number of color-enabling variables to use for
#+ painting terminal output.
#.
## Arguments:
#+ _none_
#.
## Returns:
#+ 0  — Always
#.
## Provides into the global scope:
#+ $RED, $GREEN, $YELLOW, $WHITE  — Insert any of these into a string to start 
#+                                  coloring text
#+ $BOLD, $REVERSE                — Insert any of these into a string to start 
#+                                  formatting
#+ $NORMAL                        — Insert this into a string to disable all of 
#+                                  the above
#.
## Prints:
#+ _nothing_
__declare_global_colors()
{
  local num_of_colors
  # get number of colors supported by terminal
  if which tput &>/dev/null; then
    num_of_colors=$( tput colors )
  fi
  # assigning global color variables
  if [ -t 1 ] && [ -n "$num_of_colors" ] && [ "$num_of_colors" -ge 8 ]; then
    # foreground colors
    readonly RED="$( tput setaf 1 )"
    readonly GREEN="$( tput setaf 2 )"
    readonly YELLOW="$( tput setaf 3 )"
    readonly WHITE="$( tput setaf 7 )"
    # effects
    readonly BOLD="$( tput bold )"
    readonly REVERSE="$( tput rev )"
    # reset
    readonly NORMAL="$( tput sgr0 )"
  else
    # foreground colors
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly WHITE=''
    # bold
    readonly BOLD=''
    readonly REVERSE=''
    # reset
    readonly NORMAL=''
  fi
  return 0
}

## Prints provided message in red-colored ‘Warning’ theme
## $1 - message text
## $2 - message sub-text (not bold)
__print_warning()
{
  __print_colored_msg $RED '!!!' Warning "$1" "$2"
}

## Prints provided message in yellow-colored ‘Installing’ theme
## $1 - message text
## $2 - message sub-text (not bold)
__print_processing()
{
  __print_colored_msg $YELLOW '>>>' Processing "$1" "$2"
}

## Prints provided message in green-colored ‘Installed’ theme
## $1 - message text
## $2 - message sub-text (not bold)
__print_done()
{
  __print_colored_msg $GREEN vvv Done "$1" "$2"
}

## Prints provided message in white-colored ‘Ignoring’ theme
## $1 - message text
## $2 - message sub-text (not bold)
__print_ignoring()
{
  __print_colored_msg $WHITE '---' Ignoring "$1" "$2"
}

## Prints provided message, along with textual icon and title, in colored theme,
#. e.g. '>>> Success: Operation completed'
## $1 - color of the message’s theme
## $2 - textual icon of the message, e.g. ‘>>>’
## $3 - title of the message, e.g. ‘Success’
## $4 - content of the message
## $5 - subcontent of the message (not bold)
__print_colored_msg()
{
  local color=$1; shift
  local icon=$1; shift
  local title=$1; shift
  local content=$1; shift
  local subcontent=$1; shift
  [ -n "$icon" ] && printf "${BOLD}${color}${REVERSE}%s${NORMAL} " "$icon"
  [ -n "$title" ] && printf "${BOLD}${color}%s:${NORMAL} " "$title"
  [ -n "$content" ] && printf "${BOLD}%s${NORMAL} " "$content"
  printf "%s\n" "$subcontent"
}

## Prints provided text within a plaque of provided color
## $1 - color of the plaque
## $2 - width of the plaque (actual width will be larger by 2)
## $* - text to print
__print_colored_plaque()
{
  local color=$1; shift
  printf "${BOLD}${color}${REVERSE}%s${NORMAL}\n" "$( __print_plaque "$@" )"
}

## Prints provided text centered within a plaque of provided width, truncating 
#. the text to plaque’s width if necessary
## $1 - width of the plaque (actual width will be larger by 2)
## $* - text to print
__print_plaque()
{
  local span_width=$1; shift
  [[ ! $span_width =~ ^[0-9]+$ ]] && span_width=32
  local message="${*:0:$span_width}"
  local message_width=${#message}
  local left_pad
  local right_pad
  let "right_pad = ( span_width - message_width ) / 2"
  let "left_pad = span_width - message_width - right_pad"
  printf ' %.0s' $(seq 0 $left_pad)
  printf '%s' "$message"
  printf ' %.0s' $(seq 0 $right_pad)
  printf '\n'
}

main "$@"
