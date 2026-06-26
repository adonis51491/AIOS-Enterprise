Write-Host "AIOS local check started"
npm run build
npm run lint
npm test --if-present
Write-Host "AIOS local check finished"
