# os-debian
![GitHub contributors](https://img.shields.io/github/contributors/goranbr/os-debian?color=green)
![GitHub commit activity](https://img.shields.io/github/commit-activity/m/goranbr/os-debian?color=green)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/goranbr/os-debian)
![GitHub All Releases](https://img.shields.io/github/downloads/goranbr/os-debian/total)
![GitHub language count](https://img.shields.io/github/languages/count/goranbr/os-debian)
![GitHub top language](https://img.shields.io/github/languages/top/goranbr/os-debian)

Debian related scripts, cheatsheets and whatnot.

## Distribution upgrades
- upgrade-debian.sh

## Renaming scripts
### ix
- ix - rename files with a basename and an index number
- **Syntax**: `ix [-w width] [-d delta] [-s start] [-n basename] [FILE]...`
- **Example**: `ix -s10 -d5 -n docker-course *.txt`

### mx
- mx - rename files and directories with a sed-like substitute syntax
- **Syntax**: `mx "pattern-string/replace-string" [FILE]...`
- **Example**: `$ mx "stupid/unwise" myfile`

