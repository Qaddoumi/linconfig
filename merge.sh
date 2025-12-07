git switch quickshell
sleep 1
echo "---------------------------------"
echo "Switched to quickshell"
echo "---------------------------------"
git push -u origin
sleep 1
echo "---------------------------------"
echo "Pushed quickshell to origin"
echo "---------------------------------"
git merge testing
sleep 1
echo "---------------------------------"
echo "Merged testing into quickshell"
echo "---------------------------------"
git add .
sleep 1
echo "---------------------------------"
echo "Added changes to quickshell"
echo "---------------------------------"
git commit --allow-empty-message -m ""
sleep 1
echo "---------------------------------"
echo "Committed changes to quickshell"
echo "---------------------------------"
git push
sleep 1
echo "---------------------------------"
echo "Pushed quickshell to origin"
echo "---------------------------------"
git switch testing
sleep 1
echo "---------------------------------"
echo "Switched to testing"
echo "---------------------------------"
git push -u origin
sleep 1
echo "---------------------------------"
echo "Pushed testing to origin"
echo "---------------------------------"
