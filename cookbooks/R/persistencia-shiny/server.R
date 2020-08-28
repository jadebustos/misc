library(shiny)
library(ggplot2)
library(scales)
library(grid)

#
# (c) 2015 Jose Angel de Bustos Perez <jadebustos@gmail.com>
#
# License: GPLv2 http://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html
#

# Server logic to show results
shinyServer(function(input, output) {
  
  # Results as shown automatically on data change:
  #
  #  1) It is "reactive" and therefore should re-execute automatically
  #     when data change
  #  2) Its output type is a plot and a table
  
  output$distPlot <- renderPlot({

    # Number of operations when Rest is used
    operacionesRest <- data.frame(
      group = c("Escritura", "Lectura"),
      value = c(6, 4)
    )
    
    # Number of operations when poolling is used
    operacionesPoolling <- data.frame(
      group = c("Escritura", "Lectura"),
      value = c(3, 1 + round(input$tTareas/input$tPoolling))
    )
    
    # Data frame with stats from pooling and rest methods
    restData <- c(100*operacionesRest$value[1]/sum(operacionesRest$value), round(100*operacionesRest$value[2]/sum(operacionesRest$value), digits=2))
    poollingData <- c(round(100*operacionesPoolling$value[1]/sum(operacionesPoolling$value), digits=2), round(100*operacionesPoolling$value[2]/sum(operacionesPoolling$value), digits = 2))
    
    finalData <- data.frame(restData, poollingData)
    
    # col and row names
    colnames(finalData) <- c("Rest", "Poolling")
    rownames(finalData) <- c("Escritura (%)", "Lectura (%)")
    
    # final data frame with all data
    finalData <- cbind(Operación=rownames(finalData), finalData)
    
    # table to be shown
    output$table1 <- renderDataTable(finalData,  options = list(paging = FALSE, searching = FALSE))
    
    # base plot when rest is used
    bpRest <- ggplot(operacionesRest, aes(x="", y=value, fill=group)) + 
      geom_bar(width = 1, stat = "identity") + ggtitle("Operaciones en modo Rest") + 
      theme(axis.ticks=element_blank(),
            axis.title=element_blank(),
            axis.text.y=element_blank()) 
    
    # pie plot when rest is used
    pieRest <- bpRest + coord_polar("y", start=0) + geom_text(aes(y = value/3 + 
                c(0, cumsum(value)[-length(value)]),label=""), size=5)
    
    # base plot when poolling is used
    bpPoolling <- ggplot(operacionesPoolling, aes(x="", y=value, fill=group)) + 
      geom_bar(width = 1, stat = "identity") + ggtitle("Operaciones en modo Poolling") + 
      theme(axis.ticks=element_blank(),
            axis.title=element_blank(),
            axis.text.y=element_blank()) 
    
    # pie plot when poolling is used
    piePoolling <- bpPoolling + coord_polar("y", start=0) + geom_text(aes(y = value/3 + 
              c(0, cumsum(value)[-length(value)]),label = ""), size=5)
    
    # grid to print both plots
    numPlots = 2
    
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(1,2)))
    
    print(pieRest, vp=viewport(layout.pos.row = 1, layout.pos.col = 1))
    print(piePoolling, vp=viewport(layout.pos.row = 1, layout.pos.col = 2))
    
    })
})