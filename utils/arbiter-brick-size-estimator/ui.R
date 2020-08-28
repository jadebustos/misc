## ui.R ##
library(shinydashboard)
#library(DT)

header <- dashboardHeader(title = "Arbiter brick size estimator",
                          tags$li(class = "dropdown",
                                  tags$a(href = "https://github.com/jadebustos/utils/arbiter-brick-size-estimator", 
                                         target = "_blank", 
                                         tags$img(height = "20px", 
                                                  src = "github.png")
                                  )
                          )
                          )

sidebar <- dashboardSidebar(
  br(),
  sidebarMenu(
    fileInput("file1", "Choose CSV File",
              accept = c(
                "text/csv",
                "text/comma-separ  ated-values,text/plain",
                ".csv")
    ),
    tags$hr(),
    textInput("databrickSize", "Largest data brick size (GB)", "500"),
    radioButtons(inputId = "brickUnit", label = "Select brick unit:",
                 c("KB" = 1,
                   "MB" = 2,
                   "GB" = 3,
                   "TB" = 4)),
    tags$hr(),
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard")    
      )
    )
)

body <- dashboardBody(
  tabItems(
    tabItem("dashboard",
            fluidRow(
              plotOutput("dataHistogram")
              )
    )
  )
)

dashboardPage(
  skin="red",
  header,
  sidebar,
  body
)
