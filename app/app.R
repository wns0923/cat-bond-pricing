# app/app.R
library(shiny); library(ggplot2); library(dplyr); library(tidyr); library(tibble)

sim <- readRDS('sim_data.rds')    # columns: max_loss, stock, bond (100,000 simulated years)
mk  <- readRDS('mkt_coef.rds')    # a, b (market line), rf (risk-free rate)

ell_fun <- function(L, A, D) pmin(1, pmax(0, (L - A) / (D - A)))
cvar    <- function(r, a = 0.05) mean(r[r <= quantile(r, a)])

ui <- fluidPage(
  titlePanel('Hurricane Cat Bond Pricing and Portfolio Explorer'),
  sidebarLayout(
    sidebarPanel(
      sliderInput('attach',  'Attachment point (USD billions of loss)', min = 25,  max = 450, value = 224, step = 5),
      sliderInput('exhaust', 'Exhaustion point (USD billions of loss)', min = 100, max = 500, value = 334, step = 5),
      sliderInput('w_cat', 'Cat bond weight in portfolio', min = 0, max = 40, value = 10, step = 1, post = '%'),
      sliderInput('stock_share', 'Stock share of the rest (remainder is bonds)', min = 0, max = 100, value = 60, step = 5, post = '%'),
      helpText('The default 224 to 334 is the Mezzanine tranche from the analysis.'),
      hr(),
      helpText('Hurricane losses: 100,000 simulated years from a generalized Pareto tail and Poisson frequency fitted to NOAA 1980-2024 (total economic losses). Spread: market line fitted on 38 Artemis deals (noisy, R-squared about 0.39). Hurricanes assumed independent of markets. Educational project, not investment advice.')
    ),
    mainPanel(
      h4('Tranche risk and price'),
      tableOutput('tranche'),
      textOutput('warn'),
      h4('Simulated loss curve'),
      plotOutput('ep', height = 280),
      h4('Portfolio return distribution'),
      plotOutput('ret', height = 280),
      h4('Portfolio comparison'),
      tableOutput('metrics')
    )
  )
)

server <- function(input, output, session) {
  
  tr <- reactive({
    validate(need(input$exhaust > input$attach, 'Exhaustion must be above attachment.'))
    ell <- ell_fun(sim$max_loss, input$attach, input$exhaust)
    el  <- mean(ell)
    validate(need(el > 0, 'Expected loss is zero at these settings. Lower the attachment point.'))
    list(ell = ell, el = el, spread = exp(mk$a + mk$b * log(el * 100)) / 100)
  })
  
  port <- reactive({
    t <- tr(); w <- input$w_cat / 100; s <- input$stock_share / 100
    cat_ret <- mk$rf + t$spread - t$ell
    base    <- s * sim$stock + (1 - s) * sim$bond
    list(without = base, with = (1 - w) * base + w * cat_ret)
  })
  
  output$tranche <- renderTable({
    t <- tr()
    tibble(`Expected loss`          = sprintf('%.2f%%', 100 * t$el),
           `Market-implied spread`  = sprintf('%.2f%%', 100 * t$spread),
           `Spread / expected loss` = sprintf('%.1fx', t$spread / t$el),
           `P(attach)`              = sprintf('%.2f%%', 100 * mean(sim$max_loss > input$attach)),
           `P(exhaust)`             = sprintf('%.2f%%', 100 * mean(sim$max_loss >= input$exhaust)))
  })
  
  output$warn <- renderText({
    el_pct <- 100 * tr()$el
    if (el_pct < 0.61 || el_pct > 6.14)
      'Warning: expected loss is outside the 0.61% to 6.14% range of the benchmark deals, so this spread is an extrapolation.'
    else ''
  })
  
  output$ep <- renderPlot({
    rp <- exp(seq(log(1.05), log(1000), length.out = 300))
    d  <- tibble(rp = rp, loss = quantile(sim$max_loss, 1 - 1 / rp, names = FALSE))
    ggplot(d, aes(rp, loss)) + geom_line() +
      geom_hline(yintercept = c(input$attach, input$exhaust), linetype = 'dashed', color = 'red') +
      scale_x_log10() +
      labs(x = 'Return period (years)', y = 'Largest hurricane loss in a year (USD billions)',
           subtitle = 'Red dashed lines: attachment and exhaustion points')
  })
  
  output$ret <- renderPlot({
    p <- port()
    tibble(`Without cat bond` = p$without, `With cat bond` = p$with) |>
      pivot_longer(everything(), names_to = 'portfolio', values_to = 'ret') |>
      ggplot(aes(ret, fill = portfolio)) +
      geom_histogram(bins = 80, alpha = 0.5, position = 'identity') +
      labs(x = 'Annual portfolio return', y = 'Simulated years', fill = NULL)
  })
  
  output$metrics <- renderTable({
    p <- port()
    f <- function(r) c(`Mean return` = mean(r), `Std deviation` = sd(r),
                       `Sharpe ratio` = (mean(r) - mk$rf) / sd(r),
                       `5% CVaR` = cvar(r, 0.05), `1% CVaR` = cvar(r, 0.01))
    tibble(Metric = names(f(p$without)), `Without cat bond` = f(p$without), `With cat bond` = f(p$with))
  }, digits = 3)
}

shinyApp(ui, server)