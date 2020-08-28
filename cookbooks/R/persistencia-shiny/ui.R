library(shiny)

#
# (c) 2015 Jose Angel de Bustos Perez <jadebustos@gmail.com>
#
# License: GPLv2 http://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html
#

#
# This simple application is used to show how many operations would be used when a mechanism of poolling or and api rest are used
# per task in a service that I am designing
#

# GUI
shinyUI(fluidPage(
  
  # Title
  titlePanel("Análisis de operaciones en persistencia"),
  
  sidebarLayout(
    sidebarPanel(
      # Mean time for finished tasks
      sliderInput("tTareas",
                  "Tiempo medio de finalización de tareas (mins):",
                  min = 1,
                  max = 50,
                  value = 30),
      # Mean time for poolling
      sliderInput("tPoolling",
                  "Tiempo medio de pooling (mins):",
                  min = 1,
                  max = 20,
                  value = 5)
    ),
    
    # Show a plot and a table with data
    mainPanel(
      plotOutput("distPlot"),
      dataTableOutput("table1")
  )
  )
))