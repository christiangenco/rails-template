# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "alpinejs", to: "https://cdn.jsdelivr.net/npm/alpinejs@3.14.3/dist/module.esm.js"
pin "alpine-turbo-drive-adapter", to: "https://cdn.jsdelivr.net/npm/alpine-turbo-drive-adapter@2.1.0/dist/alpine-turbo-drive-adapter.esm.js"
pin "@alpinejs/collapse", to: "https://cdn.jsdelivr.net/npm/@alpinejs/collapse@3.14.3/dist/module.esm.js"

pin_all_from "app/javascript/alpine", under: "alpine"
pin_all_from "app/javascript/utils", under: "utils"
