for i in $fish_function_path
	if test -d $i ; set existing_paths $existing_paths $i ; end
end
source (find $existing_paths -name 'gh-issue.fish')
for option in (functions | grep gh-issue- | awk -F 'gh-issue-' '{print $2}')
        complete -c gh-issue -a $option
end
