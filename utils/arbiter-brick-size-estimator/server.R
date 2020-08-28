#library(DT)
library(ggplot2)

server <- function(input, output) {

  output$dataHistogram <- renderPlot({
    inputFile = input$file1
    
    if (is.null(inputFile))
      return(NULL)
    
    originalData <- read.csv(inputFile$datapath, header=TRUE, sep=";")
    
    originalData[,2] <- as.numeric(originalData[,2])
    originalData[,1] <- as.factor(originalData[,1])
    
    data <- c()
    for(i in 1:ncol(originalData))
    {
      for(j in 1:originalData[i,2])
      {
        data <- c(data, is.numeric(originalData[i,1]))            
      }
    }

    dataMean <- mean(data)
    dataSD <- sd(data)
    dataVariance <- var(data)
    
    # largestDataBrickSize in kb  
    largestDataBrickSize <- input$databrickSize
    
    if ( input$brickUnit == 2 )
      largestDataBrickSize <- largestDataBrickSize * 1024
    else if ( input$brickUnit == 3 )
      largestDataBrickSize <- largestDataBrickSize * 1024 *1024
    else if ( input$brickUnit == 4)
      largestDataBrickSize <- largestDataBrickSize * 1024 * 1024 * 1024
    
    #minBrickSize <- 4 * (largestDataBrickSize/dataMean)
      
    p <- ggplot(originalData, aes(x=Size,y=Count)) +
      geom_bar(stat="identity") +
      xlab("Size (kb)")

    p
    
  })  
  
}
