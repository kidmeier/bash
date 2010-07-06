function current-project() {

    dir=$PWD
    while test ! -f $dir/.project
    do
        echo $dir
        dir = `readlink -f "$dir/.."`
    done
    basename $dir
}

function git-eclipse-diff() {

    proj=$(current-project)
#    echo $(cat<<<HEADER
### Eclipse Workspace Patch 1.0                                                 
#P $proj\n                                                                      
#HEADER
#;git diff --no-prefix) | less

}
