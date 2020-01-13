# os-debian
Debian related scripts, cheatsheets and whatnot.

## Distribution upgrades
- upgrade-debian.sh

## Renaming scripts
### mx
- mx - rename files and directories with a sed-like substitute syntax
- Syntax: `mx "pattern-string/replace-string" FILEPATTERN`
- Example: `$ mx "stupid/unwise" myfile`

### ix
- ix - rename files with a basename and an index number
- Syntax: `ix [-w width] [-d delta] [-s start] [-n basename] FILEPATTERN`
- Example: `ix -s10 -d5 -n docker-course *.txt`
