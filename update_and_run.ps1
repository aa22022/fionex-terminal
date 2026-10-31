$Path = "C:\Users\Cisco\Desktop\gold_predictor"
Set-Location $Path

# اجرای ماژول آپدیت به صورت بی صدا
Start-Process julia -ArgumentList "-e 'include(\"src/main.jl\");'" -NoNewWindow -Wait
