source $HOME/.config/fish/functions/gh-issue.fish
for option in (functions | grep gh-issue- | awk -F 'gh-issue-' '{print $2}')
        complete -c gh-issue -a $option
end
