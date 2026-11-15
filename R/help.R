# In-app guide: what the tool shows, why the lunar south pole, how sites are judged.

helpUI <- function(sources, has_ml = FALSE) {
  rn <- function(id) sprintf("[%d]", match(id, sources$sources$id))
  div(class = "help-backdrop", id = "help", role = "dialog", `aria-modal` = "true", `aria-labelledby` = "help-title",
    div(class = "help-card",
      tags$button(type = "button", class = "help-close", `aria-label` = "Close", HTML("&times;")),
      h2(id = "help-title", "How to read the Lunar Navigator"),
      p(class = "lead", strong("We compare potential landing areas by terrain, illumination and Earth visibility."), " Near the lunar south pole, with NASA data, for a mission period you choose, and we show how robust each result is."),
      div(class = "help-grid",
        div(class = "help-sec",
          h3("1 · Why the south pole?"),
          tags$ul(
            tags$li(strong("Water ice. "), "Crater floors that never see sunlight (permanently shadowed regions) are cold enough to trap ice, a resource for drinking water, oxygen and fuel."),
            tags$li(strong("Power. "), "On raised rims and ridges the Sun skims the horizon and can stay visible for long periods, which is good for solar panels."),
            tags$li(strong("Communication. "), "Earth hangs low over the horizon; where it stays visible, a lander can talk to Earth directly."),
            tags$li(strong("Artemis. "), paste0("NASA's crewed landing regions all lie here ", rn("nasa2024"), "."))
          )),
        div(class = "help-sec",
          h3("2 · What the map shows"),
          tags$ul(
            tags$li(strong("Pins "), "are published landing points. Click one to open its dossier: how it compares with the others, the ground around it at 80 m, light and radio contact over the year. Click anywhere else to analyse your own point."),
            tags$li(strong("Diamonds "), "mark every previous landing (NASA NSSDCA). Filled = landed, hollow = tipped over, × = crashed, dashed circle = planned. They open a dossier too, so you can see why IM-1 tipped over."),
            tags$li(strong("Map layer "), "colours every location: ", span(class = "sw sw-lo"), " orange = poor, ", span(class = "sw sw-hi"), " green = good."),
            tags$li(strong("Landing suitability "), "combines flat terrain, long-term sunlight and Earth visibility (80–90° S, where high-resolution LOLA data exist)."),
            if (has_ml) tags$li(strong("ML · NASA-likeness "), "a machine-learning model trained on NASA's nine Artemis regions shows where the terrain looks like them (white dashed outlines)."),
            tags$li(strong("Compare tab "), "puts every site side by side for your mission window, or one site across 12 lunar months, with hour-by-hour Sun and Earth windows and how long until sunset and Earthset."),
            tags$li(strong("Dashed outlines "), "are NASA's nine Artemis landing regions (2024). How robust their ranking is, and how our numbers compare with a published analysis, is shown at the top of Data & Methods."),
            tags$li(strong("Window layers "), "show when Sun and Earth are above the horizon in your mission period, for the whole Moon. They use a smooth Moon without mountains, so they answer when, not where.")
          )),
        div(class = "help-sec",
          h3("3 · How sites are scored"),
          tags$ul(
            tags$li(strong("Three criteria, all with real terrain: "), "flat ground within 1 km (LOLA), long-term sunlight and long-term Earth visibility (Mazarico et al. 2011)."),
            tags$li(strong("Score 0 to 100 "), "= weighted mean of the three, using the sliders on the left. It is absolute: adding a place never changes another place's score. The Landing score map uses the same formula."),
            tags$li(strong("The mission window "), "decides when to land (light, radio contact, longest night), not where.")
          )),
        div(class = "help-sec help-wide",
          h3("What this tool is, and what it is not"),
          tags$ul(
            tags$li(strong("It is "), "a transparent, reproducible comparison of candidate landing areas. It builds on NASA data (LOLA, Mazarico et al.), the USGS outlines of NASA's nine Artemis regions and published site studies, and adds a robustness test and checks against real landings."),
            tags$li(strong("It is not "), "a landing-site certification and it does not claim to find the one best spot. With 80 m pixels it compares areas; boulders and craters smaller than about 100 m are invisible, as the IM-2 landing showed. Final site selection needs 1 to 5 m data and engineering constraints of the specific lander.")
          )),
        div(class = "help-sec",
          h3("4 · Try it"),
          tags$ol(
            tags$li("Pick a mission start and duration (top left)."),
            tags$li("Choose a map layer and watch where it turns green."),
            tags$li("Move the weight sliders and the ranking on the right updates."),
            tags$li("Select a site and open ", strong("Why here?"), " for strengths, weaknesses and the best landing window."),
            tags$li("Press ▶ under the chart to animate Sun and Earth over the period.")
          ))),
      div(class = "help-gloss",
        h3("Glossary"),
        tags$dl(
          tags$dt("Slope"), tags$dd("Steepness of the ground in degrees (LOLA laser altimeter). Landers need gentle slopes."),
          tags$dt("Permanently shadowed region"), tags$dd("Ground that receives no direct sunlight over the 18.6-year lunar cycle."),
          tags$dt("Direct-to-Earth (DTE)"), tags$dd("Radio link to Earth without a relay satellite; needs Earth above the local horizon."),
          tags$dt("Skyline"), tags$dd("The real horizon set by mountains and crater rims, from the LOLA elevation model. Mission-window values use it; only the map's window layers use a smooth sphere."),
          if (has_ml) tags$dt("ML score"), if (has_ml) tags$dd("Percentile 0–100: a score of 90 means the place is more similar to NASA's selected regions than 90 % of the south-polar terrain. It learns NASA's selection pattern; it does not know the 'best' site."),
          tags$dt("Provenance badges"), tags$dd("Computed, Measured, Literature, Not ingested: every number says where it comes from. Full list under Data & Methods."))),
      div(class = "help-foot",
        tags$button(type = "button", class = "help-ok", "Start exploring"),
        span(class = "muted small", "Reopen this guide any time with ?"))))
}
