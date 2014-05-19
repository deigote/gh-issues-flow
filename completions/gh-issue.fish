source (find (echo $fish_function_path | xargs ls -d 2>/dev/null) -name 'gh-issue.fish')
for option in (functions | grep gh-issue- | awk -F 'gh-issue-' '{print $2}')
        complete -c gh-issue -a $option
end
