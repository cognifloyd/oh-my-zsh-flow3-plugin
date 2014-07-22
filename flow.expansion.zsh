#
# Expands a package directory for in all parameters starting with $3.
# $1 defines the a folder within the package directory that should be
# included after the package directory, but before the rest. For example:
#      var=$(_flow_package_dir_expansion $flowBaseDir Tests/Unit P/TYPO3.Flow/Cli)
#      var=$(_flow_package_dir_expansion $flowBaseDir Tests/Unit P:TYPO3.Flow:Cli)
#        echoes <flowBaseDir>/Packages/Framework/TYPO3.Flow/Tests/Unit/Cli
#      var=$(_flow_package_dir_expansion $flowBaseDir Tests/Unit P:TYPO3.Flow)
#        echoes <flowBaseDir>/Packages/Framework/TYPO3.Flow/Tests/Unit
#
_flow_package_dir_expansion() {
  local expandedDirs
  local packageDir
  local flowBaseDir=${1%%/} #remove trailing slash(es)
  local dirInPkg=${2##/}    #remove initial slash(es)
  dirInPkg=${dirInPkg%%/}   #remove trailing slash(es)
  shift
  shift

  for entry in $@; do
    if _flow_can_expand $entry; then
      # Assume that the package key does not have / or : in it.

      local -A nameParts #Associative Array
        # nameParts[package]
        # nameParts[dirInPkg]
        # nameParts[localPath]

      nameParts=($(_flow_parse_namestr $entry)) #don't strip P: or P/ from $entry
      packageDir=$(_flow_list_packages $flowBaseDir | grep -i /$nameParts[package]/)

      # packageDir includes a trailing slash! dirInPkg doesn't.
      entry=${packageDir}${dirInPkg}/$nameParts[package]
    fi
    expandedDirs+=" $entry"
  done

  echo ${expandedDirs# } #remove initial space
}

############################################
# Section: ZSH Dynamic Directory Expansion #
############################################

# add our custom expansion function
# For details on how this works, see zshexpn(1) or http://superuser.com/a/751637
zsh_directory_name_functions+=(_flow_directory_name_expansion)

_flow_directory_name_expansion() {
  emulate -L zsh
  setopt extendedglob
  local -a match mbegin mend #arrays
  case $1 in
    d) #d: checking if the current directory is a named directory
      _flow_expand_directory_to_name $2
      return
      ;;
    n) #n: map a name to a directory
      _flow_expand_name_to_directory $2
      return
      ;;
    c) #c: provide a list of names for completion
      _flow_complete_directory_names $2
      return
      ;;
    *) #error, unknown expansion mode! 
      return 1
      ;;
  esac
}

#
# turn the directory into a name
#
# From zshexpn(1):
# "used to see if a directory can be turned into a name,
# for example when printing the directory stack or when expanding %~ in prompts."
#
# "function is passed ... the candidate for dynamic naming."
#
# "The function should either
#   return non-zero status, if the directory cannot be named by the function, or
#   it should set the array reply to consist of two elements:
#     the first is the dynamic name for the directory (as would appear within `~[...]'), and
#     the second is the prefix length of the directory to be replaced."
#
_flow_expand_directory_to_name() {
  return 1 # not implemented
  local dynamicName prefixLength
  local candidateDir=$1

  dynamicName="P:"
  prefixLength=""

  #zsh uses $reply
  typeset -ga reply #global arrary
  reply=($dynamicName $prefixLength)
  return 0

  return 1
}

#
# turn the name into a directory
#
# From zshexpn(1):
# "function is passed ... namestr" (where namestr is "treated specially as a dynamic directory name")
#
# "It should either"
#   "return status non-zero" or
#   "return status zero (executing an assignment as the last statement is usually sufficient)" and
#     "set the array reply to a single element which is the directory corresponding to the name"
#     "the element of reply is used as the directory"
#
_flow_expand_name_to_directory() {
  #return if this can't handle this.
  ! _flow_can_expand $1 && return 1
  local -A nameParts #Associative Array
    # nameParts[package]
    # nameParts[dirInPkg]
    # nameParts[localPath]
  local flowBaseDir packageDir expandedDir 

  # set $flowBaseDir
  _flow_get_flowBaseDir || return 1

  nameParts=($(_flow_parse_namestr $1)) #don't strip P: or P/ from $1
  packageDir=$(_flow_list_packages $flowBaseDir | grep -i /$nameParts[package]/)

  # packageDir includes a trailing slash! dirInPkg doesn't.
  expandedDir=${packageDir}$nameParts[dirInPkg]${nameParts[dirInPkg]:+/}$nameParts[localPath]

  #zsh uses $reply
  typeset -ga reply #global arrary
  reply=($expandedDir)
  return 0
}

#
# provide a list of names for completion
#
# From zshexpn(1):
# "The code for this should be as for any other completion function as described in zshcompsys(1)."
#
_flow_complete_directory_names() {
  local flowBaseDir startingDir package expl
  local -a packageDirs dirsInPkg dirs names
  #local -a dirs
  local -A possibleDirsInPkg

  # set $flowBaseDir
  _flow_get_flowBaseDir || return 1

  # P:<package>:[<dirInPkg>:][<localPath>]
  packageDirs=(${$(_flow_list_packages $flowBaseDir)%%/}) # remove trailing slash
  #add dirInPkg entries if they exist
  possibleDirsInPkg=(
      'Classes'           'C'
      'Configuration'     'Co'
      'Tests/Unit'        'TU'
      'Tests/Functional'  'TF'
      'Tests/Behavior'    'TB'
      'Tests'             'T'
      'Resources/Public'  'RPu'
      'Resources/Private' 'RPr'
      'Resources'         'R'
      'Documentation'     'D'
      'Migrations'        'M'
      )

  startingDir=`pwd`
  for packageDir in $packageDirs; do
    cd $packageDir
    dirsInPkg=($(find * */* -prune -type d))
    # Find the intersection of the arrays.
    #   Requires zsh 5.0+ (included in OSX 10.9; For 10.8 and older, you must use homebrew or similar to install zsh)
    dirsInPkg=(${(k)possibleDirsInPkg:*dirsInPkg})
    #dirs=($dirs $packageDir $packageDir/${^dirsInPkg})

    #P:<package>[:[<dirInPkg>:]<localPath>]
    package=P:${packageDir##*/} #remove everything before the last /
    names=($names $package)
    for dirInPkg in $dirsInPkg; do
      #skip localPath for now
      #TODO: <localPath> support goes here

      #dirsInPkg musta always be followed by a colon
      names=($names $package:${^possibleDirsInPkg[$dirInPkg]}:)
    done
  done
  cd $startingDir

  #two relevant vars: $names $dirs
  #see zshcompsys(1)
  _wanted dynamic-dirs expl 'flow package directories' compadd -S\] -a names
  return
}

#
# Returns 0 if we can expand this directory
#
_flow_can_expand() {
  if [[ ${1:0:2} == "P:" ]] || [[ ${1:0:2} == "P/" ]]; then
    return 0
  fi
  return 1
}

#
# sets $flowBaseDir (be sure to create this as local in calling function)
# or returns 1 if it can't be found
#
_flow_get_flowBaseDir() {
  if _flow_is_inside_base_distribution; then
    local startDirectory=`pwd`
    while [[ ! -f flow ]]; do
      cd ..
    done
    flowBaseDir=`pwd`
    cd $startDirectory
  else
    #get directory from cdpath settings if we're not in a flow distribution
    if [[ -f $ZSH/custom/plugins/flow/f-environment-choice.txt ]]; then
      flowBaseDir=`cat $ZSH/custom/plugins/flow/f-environment-choice.txt`
    fi
    # if $flowBaseDir isn't set, you must not have used f-set-distribution
  fi
  [[ -n $flowBaseDir ]] # this sets the return value. If set return 0. If not set return 1.
}

#
# Parses a namestr in one of these formats:
#    P:<package>[:[<dirInPkg>:]<localPath>]
#    P/<package>[:[<dirInPkg>:]<localPath>]
#    P:<package>[/[<dirInPkg>:]<localPath>]
#    P/<package>[/[<dirInPkg>:]<localPath>]
#  So, use : or / around <package>, but <dirInPkg> must be followed by : to prevent ambiguity
#
#  Echoes a multiline string (dirInPkg may or may not be included):
#    package <package>
#    dirInPkg <dirInPkg>
#    localPath <localPath>
#
#  Usage: use this in an associative array ($() replaces new lines with spaces)
#    local -A nameParts
#    nameParts=$(_flow_parse_namestr $namestr)
#
_flow_parse_namestr() {
  local namestr=${1:2} # remove "P/" or "P:"
  local -a namestr_parts # array

  #regularize the namestr
  if [[ ! $namestr == *:* ]]; then
    # namestr was <package>/<localPath>
    # make it be  <package>:<localPath>
    namestr=${namestr/\//:} # 

    if [[ ! $namestr == *:* ]]; then
      # namestr was <package>
      # make it be  <package>:
      namestr=${namestr}:
    fi
  fi
  # should now be <package>:[<dirInPkg>:][<localPath>]

  namestr_parts=("${(s/:/)namestr}")

  #<package>
  echo package $namestr_parts[1]

  #:<dirInPkg>:
  if [[ ! $namestr_parts[-1] = $namestr_parts[2] ]]; then
    local dirInPkg=${namestr_parts[2]##/} #remove initial slash(es)
    dirInPkg=${dirInPkg%%/}               #remove trailing slash(es)
    #parse special dirInPkg shortcuts here.
    case "$dirInPkg" in
      # NOTE: This only supports one of the named entries. It does not support anything else.
      # Maybe it should support <entry>/*, but that's a project for another day.
      'C' )
        #Parses to Classes by default, but the caller may expand further to Classes/<package>
        dirInPkg='Classes'
        ;;
      'Co' | 'Config' )
        #Should this allow Co? I don't want to confuse composer.json
        dirInPkg='Configuration'
        ;;
      'TU' | 'T/U' | 'T/Unit' )
        dirInPkg='Tests/Unit'
        ;;
      'TF' | 'T/F' | 'T/Func' | 'T/Functional' )
        dirInPkg='Tests/Functional'
        ;;
      'TB' | 'T/B' | 'T/Behavior' )
        dirInPkg='Tests/Behavior'
        ;;
      'T' )
        dirInPkg='Tests'
        ;;
      'RPu' | 'R/Pu' | 'R/Public' )
        dirInPkg='Resources/Public'
        ;;
      'RPr' | 'R/Pr' | 'R/Private' )
        dirInPkg='Resources/Private'
        ;;
      'R' )
        dirInPkg='Resources'
        ;;
      'D' )
        dirInPkg='Documentation'
        ;;
      'M' )
        dirInPkg='Migrations'
        ;;
    esac
    echo dirInPkg $dirInPkg
  fi

  #:<localPath>
  if [[ -n $namestr_parts[-1] ]]; then
    echo localPath $namestr_parts[-1]
  fi
}
