'From Cuis7.7 [latest update: #7977] on 10 October 2026 at 12:00:00 pm'!
'Description The Vikix theme inside Cuis: a Theme whose colours and font follow vikix theme.

VikixTheme is the class; its colour methods (background, text, defaultWindowColor, shout, ...) and fontFamilyName are not here: vikix theme writes them, from the .theme file, into ~/.config/vikix/theme/cuis.st, a chunk file of methods of this class, and files it in. The launcher (vikix cuis run) gives the file''s path with -d ''VikixTheme loadFrom: ...'' at every start, and vikix theme sends the same through the door while the image runs, so the image follows the desktop''s theme both ways. The Vikix font (Iosevka, ~/.local/share/vikix/fonts) is read into the image at build with loadFont:, and made the default when the written class names it. Vikix''s part of Cuis: vikix cuis setup loads it (cuis/VikixTheme.pck.st in the Vikix checkout).'!
!provides: 'VikixTheme' 1 0!
SystemOrganization addCategory: #'VikixTheme'!


!classDefinition: #VikixTheme category: #'VikixTheme'!
Theme subclass: #VikixTheme
	instanceVariableNames: ''
	classVariableNames: 'Loaded Path'
	poolDictionaries: ''
	category: 'VikixTheme'!
!classDefinition: 'VikixTheme class' category: #'VikixTheme'!
VikixTheme class
	instanceVariableNames: ''!


!VikixTheme commentStamp: '<historical>' prior: 0!
The desktop's theme, as a Cuis Theme. The colours are methods vikix theme writes (see the package description); here is only what every Vikix theme shares: one colour for every window, panes in the theme's background, and how the file is loaded and made current.!

!VikixTheme methodsFor: 'colors' stamp: 'vikix 10/10/2026 12:00'!
useUniformColors
	"Every window in the theme's colour: the desktop has one accent, not one a tool."

	^ true! !

!VikixTheme methodsFor: 'colors' stamp: 'vikix 10/10/2026 12:00'!
paneBackgroundFrom: aColor
	"Lists and panes in the theme's text background, whatever the window's colour."

	^ self textPane! !

!VikixTheme methodsFor: 'colors' stamp: 'vikix 10/10/2026 12:00'!
unfocusedTextHighlightFrom: aColor
	"A selection in a pane without the focus: the theme's dim colour, as the editors do."

	^ self line! !

!VikixTheme methodsFor: 'fonts' stamp: 'vikix 10/10/2026 12:00'!
fontFamilyName
	"The font family the desktop uses, when vikix theme has written it (the Vikix font, Iosevka); nil leaves Cuis's."

	^ nil! !

!VikixTheme class methodsFor: 'loading' stamp: 'vikix 10/10/2026 12:00'!
loadFrom: aPathName
	"The chunk file vikix theme writes (~/.config/vikix/theme/cuis.st): filed in when it changed since last, then made current, font and all. False when there is no such file, and the theme stays as it is."

	| entry text |
	Path := aPathName.
	entry := FileEntry withAbsolutePathName: aPathName.
	entry exists ifFalse: [ ^ false ].
	text := entry textContents.
	text = Loaded ifFalse: [
		self fileIn: entry.
		Loaded := text ].
	self apply.
	^ true! !

!VikixTheme class methodsFor: 'loading' stamp: 'vikix 10/10/2026 12:00'!
fileIn: aFileEntry
	"The chunk file's methods into this class, as a package install files its in: under the package's own change set, or Cuis asks for a change set's name in a dialog, which a headless build and the door can't answer; then the package marked clean again, since the colours are the file's, not the package's to save."

	ChangeSet installing: 'VikixTheme' do: [
		aFileEntry readStreamDo: [ :stream | stream fileIn ]].
	(CodePackage named: 'VikixTheme' createIfAbsent: false registerIfNew: false) ifNotNil: [ :package |
		package hasUnsavedChanges: false; triggerEvent: #dirtyFlagChanged.
		ChangeSet removeChangeSet: (ChangeSet existingOrNewChangeSetForPackage: package) ]! !

!VikixTheme class methodsFor: 'loading' stamp: 'vikix 10/10/2026 12:00'!
reload
	"The file loaded last, again (vikix theme, through the door)."

	^ Path notNil and: [ self loadFrom: Path ]! !

!VikixTheme class methodsFor: 'loading' stamp: 'vikix 10/10/2026 12:00'!
path
	"Where the theme was loaded from, or nil."

	^ Path! !

!VikixTheme class methodsFor: 'loading' stamp: 'vikix 10/10/2026 12:00'!
apply
	"This theme current: the world, the menus, the syntax colours, the font, and the windows already open, which Cuis would leave in the old colours."

	self beCurrent.
	self current applyFont.
	UISupervisor ui ifNotNil: [ :world |
		world submorphsDo: [ :m |
			(m is: #SystemWindow) ifTrue: [ m setWindowColor: self current defaultWindowColor ]]]! !

!VikixTheme class methodsFor: 'loading' stamp: 'vikix 10/10/2026 12:00'!
loadFont: aPathName
	"The TrueType fonts in a folder (the Vikix font, ~/.local/share/vikix/fonts), read into the image: at build, so the saved image carries it. The family names read."

	| folder |
	folder := DirectoryEntry withAbsolutePathName: aPathName.
	folder exists ifFalse: [ ^ #() ].
	^ TrueTypeFontFamily readAllTrueTypeFontsIn: folder! !

!VikixTheme methodsFor: 'fonts' stamp: 'vikix 10/10/2026 12:00'!
applyFont
	"The written font family the system's default, when the image has it; sizes stay."

	self fontFamilyName ifNotNil: [ :name |
		(FontFamily familyNamed: name) ifNotNil: [ :family |
			FontFamily defaultFamilyName = name ifFalse: [ PreferenceSet setDefaultFont: name ]]]! !
