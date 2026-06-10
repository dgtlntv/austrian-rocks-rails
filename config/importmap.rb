# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

pin "stimulus-chartjs", to: "https://ga.jspm.io/npm:stimulus-chartjs@5.0.0/dist/stimulus-chartjs.mjs"
pin "@kurkle/color", to: "https://ga.jspm.io/npm:@kurkle/color@0.3.2/dist/color.esm.js"
pin "chart.js/auto", to: "https://ga.jspm.io/npm:chart.js@4.3.0/auto/auto.js"
pin "maplibre-gl", to: "https://ga.jspm.io/npm:maplibre-gl@5.24.0/dist/maplibre-gl.js"
pin "pmtiles", to: "https://ga.jspm.io/npm:pmtiles@4.4.1/dist/esm/index.js"
pin "fflate", to: "https://ga.jspm.io/npm:fflate@0.8.2/esm/browser.js"
