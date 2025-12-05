git switch quickshell
echo "---------------------------------"
echo "Switched to quickshell"
echo "---------------------------------"
git push -u origin
echo "---------------------------------"
echo "Pushed quickshell to origin"
echo "---------------------------------"
git merge testing
echo "---------------------------------"
echo "Merged testing into quickshell"
echo "---------------------------------"
git add .
echo "---------------------------------"
echo "Added changes to quickshell"
echo "---------------------------------"
git commit --allow-empty-message -m ""
echo "---------------------------------"
echo "Committed changes to quickshell"
echo "---------------------------------"
git push
echo "---------------------------------"
echo "Pushed quickshell to origin"
echo "---------------------------------"
git switch testing
echo "---------------------------------"
echo "Switched to testing"
echo "---------------------------------"
git push -u origin
echo "---------------------------------"
echo "Pushed testing to origin"
echo "---------------------------------"
