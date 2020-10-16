REM  *****  BASIC  *****
Option Explicit

Global Const path = "/home/ubuntu/Presentation/"
Global Const endFile = "/home/ubuntu/Control/End"

Global oDoc As Object
global oPresentation As Object
Global oController As Object	
Global oListener As Object
Global oSlideCount As Integer

Sub Main
	Dim Doc as Object
	Dim CurSlide as Object
	Dim i as Integer
	Doc = ThisComponent
	
	for i = 0 to Doc.getDrawPages().Count-1
		CurSlide = Doc.getDrawPages().getByIndex(i)
		Doc.CurrentController.setCurrentPage(CurSlide)
		if CurSlide.Change <> 1 then
			CurSlide.Change = 1
			CurSlide.Duration = 7
		end if
	next i
	
	CurSlide = Doc.getDrawPages().getByIndex(0)
	Doc.CurrentController.setCurrentPage(CurSlide)

	if FileExists(endFile) Then
		kill endFile
	end if

	addlistener
End Sub

Sub EV_slideEnded(oEv)

	' Check for end of slide show
	dim slideIndex as Integer
	slideIndex = oController.getCurrentSlideIndex + 1
	
	if slideIndex = oSlideCount then
		' If this is multifile show, write to control file, and pause
		if Multifile() then

			writeText(endFile, now)
			oController.removeSlideShowListener(oListener)
			oController.Pause()
		end if	
	end if
End Sub

Function Multifile
	' Check if we have multiple files in the folder
	dim sFile As String
	dim i As Integer
	i = 0
	sFile = Dir(path,0)
	' Check for ODP files in the presentation folder
	while sFile <> ""
		sFile = Lcase(sFile)	
		if InStr(Right(sFile, 3),"odp") then
			i = i + 1
		end if
		sFile = Dir
	wend

	if i > 1 then
		Multifile = True
	else
		Multifile = False
	end if
End Function

Sub addListener
	oDoc = ThisComponent 

	oPresentation = oDoc.Presentation
	' com.sun.star.presentation.Presentation

	oPresentation.CustomShow = ""
	oPresentation.FirstPage = "1"
	oPresentation.IsAlwaysOnTop = True
	oPresentation.IsAutomatic = False
	oPresentation.IsMouseVisible = False
	oPresentation.IsEndless =  True
	oPresentation.IsFullScreen = True
	oPresentation.IsTransitionOnClick = True
	oPresentation.AllowAnimations = True
	oPresentation.Pause = 300

	oPresentation.Start()
	wait 200

 	oListener = createUnoListener("EV_","com.sun.star.presentation.XSlideShowListener")
 	' com.sun.star.presentation.XSlideShowListener

	wait 200
	oController = oPresentation.Controller
	' com.sun.star.presentation.XSlideShowController
	
	wait 200
	
	oController.addSlideShowListener(oListener)
	oSlideCount = oController.getSlideCount()

end sub

Sub Reload
	dim document, dispatcher as Object
	document = ThisComponent.CurrentController.Frame
	dispatcher = createUnoService("com.sun.star.frame.DispatchHelper")
	dispatcher.executeDispatch(document, ".uno:Reload", "", 0, Array())
end sub

Sub writeText(myFile As String, myText As String)
	dim FileNo
	FileNo = FreeFile
	open myFile for Output as #FileNo
		print #FileNo, myText
	Close #FileNo
End Sub
