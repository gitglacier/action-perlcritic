#!/bin/bash

# Move to our main repo
cd ${GITHUB_WORKSPACE}

echo "## reviewdog --version"
reviewdog --version
echo "## perl --version"
perl --version
echo "## perlcritic --version"
perlcritic --version
echo "## cpanm -V"
cpanm -V

echo "## Running cpanm --installdeps ."
cpanm --installdeps --force --notest .

export PERL5LIB="${PERL5LIB}:$PWD/modules"
export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
FILES=`git diff --name-only origin/master | grep -P "(\.pl|\.pm|\.cgi)$"`

echo "## Running perlcritic"
perlcritic --gentle --profile .perlcriticrc $FILES |
    reviewdog -name="perlCritic" -filter-mode=file -efm="%f:%l:%c:%m" -reporter="github-pr-check"

#export ESC_GITHUB_WORKSPACE=$(echo "$GITHUB_WORKSPACE" | perl -pe 's/\//\\\//g')

# SUBSTR below puts the "perl -c format" into "file:line:error" format for reviewdog.
# (Also trims ./ or ../../ or /somedir/ from beginning of file path.)
export SUBSTR="s/(.*) at (.\/|\/github\/workspace\/|)(.*) line (\d+)(.*)/\$3:\$4:\$1/g"

echo "## Running perl -c (on *.pm)"
temp_file=$(mktemp)

for x in $FILES
do
   # check-perl essentially does "perl -cw", but also looks for "-T" (taint)
   ./scripts/bin/check-perl-porcelain $x |&  # |& makes STDERR go into STDOUT.
      perl -pe "$SUBSTR" |                   # Puts it into reviewdog efm format below.
      perl -pe "s|^-:|$x:|" >>$temp_file     # Replaces "-" with the current filename we're checking.
done

cat ${temp_file} |
   reviewdog -name="perlSyntax" -filter-mode=file  -efm="%f:%l:%m" -reporter="github-pr-check"

rm ${temp_file}
