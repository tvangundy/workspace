Set WindowBar Colorful
Set Width 1200
Set Height 400
Set FontSize 28

Type "cd examples/home-assistant"
Enter
Sleep 1s
Type "kubectl port-forward --address 0.0.0.0 svc/home-assistant -n home-assistant 8123:8123"
Enter
Sleep 10s

