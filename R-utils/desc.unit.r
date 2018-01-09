#==========================================================================================#
#==========================================================================================#
#     This function creates an expression object that has the description and the units    #
# with sub-scripts, superscripts and stuff.                                                #
#------------------------------------------------------------------------------------------#
desc.unit <<- function(desc,unit,bracket=TRUE,dxpr=FALSE){
   if (missing(desc) | missing(unit)){
      cat(" - Missing \"desc\": ",missing(desc),"\n")
      cat(" - Missing \"unit\": ",missing(unit),"\n")
      stop(" Both desc and unit must be provided")
   }#end if

   if (is.null(desc) && is.null(unit)){
      answer = ""
   }else if (is.null(unit)){
      if (dxpr){
         answer = parse(text=desc)
      }else{
         answer = desc
      }#end if
   }else if (is.null(desc)){
      if (bracket){
         answer = parse(text=paste0("paste(\"[\",",unit,",\"]\")"))
      }else{
         answer = parse(text=paste0("paste(\"\",",unit,",\"\")"))
      }#end if
   }else{
      if (dxpr){
         if (bracket){
            answer = parse(text=paste0("paste(",desc,",\" [\",",unit,",\"]\")"))
         }else{
            answer = parse(text=paste0("paste(",desc,",\" \",",unit,",\"\")"))
         }#end if
      }else{
         if (bracket){
            answer = parse(text=paste0("paste(\"",desc,"\",\" [\",",unit,",\"]\")"))
         }else{
            answer = parse(text=paste0("paste(\"",desc,"\",\" \",",unit,",\"\")"))
         }#end if
      }#end if
   }#end if

   return(answer)
}#end function
#==========================================================================================#
#==========================================================================================#
