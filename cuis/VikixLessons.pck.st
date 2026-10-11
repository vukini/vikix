'From Cuis7.7 [latest update: #7977] on 11 October 2026 at 10:00:00 am'!
'Description Lessons that change the running image: a first course in Smalltalk where the image is the exercise book.

VikixLessons open shows a window with the lessons down the left (a tick on each done), the lesson''s task, a pane to type Smalltalk in, and Check, Hint and Next. Check runs what you typed in the image (a Workspace''s doIt, so a class you define is really there) and looks at the value and the image to say whether the task is done; a lesson done stays done in the image, and vikix cuis lessons reopens the window where you were. The lessons are data on the class side (VikixLessons class lessons: a Dictionary each, title, task, hint and a check block), so a new one is a line in that list. Vikix''s part of Cuis: vikix cuis setup loads it (cuis/VikixLessons.pck.st in the Vikix checkout).'!
!provides: 'VikixLessons' 1 0!
!requires: 'VikixServer' 1 0 nil!
SystemOrganization addCategory: #'VikixLessons'!


!classDefinition: #VikixLessons category: #'VikixLessons'!
Object subclass: #VikixLessons
	instanceVariableNames: 'index code task result'
	classVariableNames: 'Done Current'
	poolDictionaries: ''
	category: 'VikixLessons'!
!classDefinition: 'VikixLessons class' category: #'VikixLessons'!
VikixLessons class
	instanceVariableNames: ''!

!classDefinition: #VikixLessonsWindow category: #'VikixLessons'!
SystemWindow subclass: #VikixLessonsWindow
	instanceVariableNames: 'list taskPane codePane status'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixLessons'!
!classDefinition: 'VikixLessonsWindow class' category: #'VikixLessons'!
VikixLessonsWindow class
	instanceVariableNames: ''!


!VikixLessons commentStamp: '<historical>' prior: 0!
The model of the lessons window: which lesson is on (index), the code typed for it, and what the last check said. The lessons themselves are on the class side (lessons), and which are done is kept in the image (Done, a Set of numbers), so a saved image keeps your progress. try: runs code as a Workspace would and checks it against the lesson; the tests drive that without a window.!

!VikixLessonsWindow commentStamp: '<historical>' prior: 0!
The window: the lessons listed on the left with a tick on each done, the task on top, the code pane under it, the buttons Check, Hint and Next, and a line saying what the last check found.!

!VikixLessons class methodsFor: 'the lessons' stamp: 'vikix 10/11/2026 10:00'!
lessons
	"The course, in order: a Dictionary a lesson with title, task (lines), hint, and check, a block given the value the code answered (nil when it failed) that answers true when the task is done. A new lesson is one more entry here."

	^ {
		self lesson: 'Numbers'
			task: 'Smalltalk is a language of messages. 3 + 4 sends the message + to 3, with 4, and 7 comes back.

Type 3 + 4 in the pane below and press Check.'
			hint: 'Just the three characters, a space each side of the plus: 3 + 4'
			check: [ :value | value = 7 ].
		self lesson: 'Words'
			task: 'A string is text in single quotes. ''hello'' reversed sends the message reversed to it, and the word comes back the other way round.

Make the word ''olleh'' from ''hello''.'
			hint: '''hello'' reversed'
			check: [ :value | value = 'olleh' ].
		self lesson: 'Many at once'
			task: 'An array is a list: #(1 2 3). collect: runs a block on each one and gathers the answers: #(1 2 3) collect: [ :n | n + 1 ] is #(2 3 4).

Make #(2 4 6) from #(1 2 3).'
			hint: '#(1 2 3) collect: [ :n | n * 2 ]'
			check: [ :value | value = #(2 4 6) ].
		self lesson: 'A box on the screen'
			task: 'Everything you see is a Morph, an object you can make. ColoredBoxMorph new openInWorld puts a new box on the screen.

Put a red box on the screen: make one, give it the colour (color: Color red), and open it. A cascade does two things to one object: ColoredBoxMorph new color: Color red; openInWorld.'
			hint: 'ColoredBoxMorph new color: Color red; openInWorld'
			check: [ :value |
				UISupervisor ui submorphs anySatisfy: [ :m | (m isKindOf: ColoredBoxMorph) and: [ m color = Color red ]]].
		self lesson: 'Your own class'
			task: 'A class is a kind of object. Make one: Object subclass: #Dog instanceVariableNames: '''' classVariableNames: '''' poolDictionaries: '''' category: ''Lessons''.

Then Check. The class list of the whole system is short enough to read: open a Browser (the World menu) and find Dog in the category Lessons.'
			hint: 'Object subclass: #Dog instanceVariableNames: '''' classVariableNames: '''' poolDictionaries: '''' category: ''Lessons'''
			check: [ :value | (Smalltalk includesKey: #Dog) and: [ (Smalltalk at: #Dog) isKindOf: Class ]].
		self lesson: 'Teach it a trick'
			task: 'A method is what an object does when it gets a message. Dog compile: ''bark ^ ''''Woof!!'''''' gives every Dog the message bark, which answers the word.

Teach Dog to bark, then check: the check asks a new Dog to bark.'
			hint: 'Dog compile: ''bark ^ ''''Woof!!'''''''
			check: [ :value |
				(Smalltalk includesKey: #Dog) and: [
					[ (Smalltalk at: #Dog) new bark = 'Woof!!' ] on: Error do: [ :ex | false ]]].
		self lesson: 'Change the image'
			task: 'You are inside the program, and it is yours to change. Transcript is the window that shows text: Transcript show: ''I changed it''; newLine writes a line there (open the Transcript from the World menu to see it).

Write any line to the Transcript.'
			hint: 'Transcript show: ''I changed it''; newLine'
			check: [ :value | value == Transcript ].
		self lesson: 'The desktop is objects too'
			task: 'Vikix draws your desktop in this image: VikixDesktop open shows a column a workspace and a box a window, read from StumpWM every second. Drag a box to another column, and the real window moves.

Open it.'
			hint: 'VikixDesktop open'
			check: [ :value | (Smalltalk includesKey: #VikixDesktop) and: [ (Smalltalk at: #VikixDesktop) window notNil ]]
	}! !

!VikixLessons class methodsFor: 'the lessons' stamp: 'vikix 10/11/2026 10:00'!
lesson: title task: task hint: hint check: aBlock

	^ Dictionary new
		at: #title put: title;
		at: #task put: task;
		at: #hint put: hint;
		at: #check put: aBlock;
		yourself! !

!VikixLessons class methodsFor: 'progress' stamp: 'vikix 10/11/2026 10:00'!
done
	"The numbers of the lessons done, kept in the image."

	^ Done ifNil: [ Done := Set new ]! !

!VikixLessons class methodsFor: 'progress' stamp: 'vikix 10/11/2026 10:00'!
reset
	"Every lesson undone again: VikixLessons reset"

	Done := Set new.
	Current := nil! !

!VikixLessons class methodsFor: 'opening' stamp: 'vikix 10/11/2026 10:00'!
open
	"The lessons, in a window, at the first one not done: VikixLessons open"

	^ VikixLessonsWindow open: self new label: 'Smalltalk lessons'! !

!VikixLessons class methodsFor: 'opening' stamp: 'vikix 10/11/2026 10:00'!
window
	"The open lessons window, or nil."

	^ UISupervisor ui ifNotNil: [ :world |
		world submorphs detect: [ :m | m isKindOf: VikixLessonsWindow ] ifNone: [ nil ]]! !

!VikixLessons class methodsFor: 'opening' stamp: 'vikix 10/11/2026 10:00'!
summary
	"A line a lesson, ticked when done, the one on marked: for vikix cuis status and the tests."

	| model |
	model := self window ifNil: [ self new ] ifNotNil: [ :w | w model ].
	^ String streamContents: [ :s |
		self lessons withIndexDo: [ :each :i |
			s nextPutAll: ((self done includes: i) ifTrue: [ '[x] ' ] ifFalse: [ '[ ] ' ]);
				print: i; space; nextPutAll: (each at: #title);
				nextPutAll: (i = model index ifTrue: [ '  <- here' ] ifFalse: [ '' ]); newLine ].
		s nextPutAll: model result ]! !

!VikixLessons methodsFor: 'initialization' stamp: 'vikix 10/11/2026 10:00'!
initialize

	index := Current ifNil: [ self class firstUndone ].
	code := ''.
	result := ''! !

!VikixLessons class methodsFor: 'progress' stamp: 'vikix 10/11/2026 10:00'!
firstUndone
	"The first lesson not done, or the last."

	self lessons withIndexDo: [ :each :i | (self done includes: i) ifFalse: [ ^ i ]].
	^ self lessons size! !

!VikixLessons methodsFor: 'accessing' stamp: 'vikix 10/11/2026 10:00'!
index

	^ index! !

!VikixLessons methodsFor: 'accessing' stamp: 'vikix 10/11/2026 10:00'!
index: aNumber
	"Go to a lesson (the list's pick, Next): remembered in the image."

	(aNumber between: 1 and: self class lessons size) ifFalse: [ ^ self ].
	index := aNumber.
	Current := aNumber.
	result := ''.
	self changed: #index; changed: #task; changed: #result! !

!VikixLessons methodsFor: 'accessing' stamp: 'vikix 10/11/2026 10:00'!
lesson

	^ self class lessons at: index! !

!VikixLessons methodsFor: 'accessing' stamp: 'vikix 10/11/2026 10:00'!
titles
	"The list's lines: a tick on each lesson done."

	^ self class lessons withIndexCollect: [ :each :i |
		((self class done includes: i) ifTrue: [ '[x] ' ] ifFalse: [ '[ ] ' ]), (each at: #title) ]! !

!VikixLessons methodsFor: 'accessing' stamp: 'vikix 10/11/2026 10:00'!
task
	"The task's text, headed with the lesson's number and title."

	^ 'Lesson ', index printString, ': ', (self lesson at: #title), String newLineString, String newLineString, (self lesson at: #task)! !

!VikixLessons methodsFor: 'accessing' stamp: 'vikix 10/11/2026 10:00'!
code

	^ code! !

!VikixLessons methodsFor: 'accessing' stamp: 'vikix 10/11/2026 10:00'!
code: aText

	code := aText asString! !

!VikixLessons methodsFor: 'accessing' stamp: 'vikix 10/11/2026 10:00'!
result
	"What the last check said."

	^ result! !

!VikixLessons methodsFor: 'checking' stamp: 'vikix 10/11/2026 10:00'!
check
	"The Check button: the code pane's text tried."

	self try: code! !

!VikixLessons methodsFor: 'checking' stamp: 'vikix 10/11/2026 10:00'!
try: aString
	"Run aString as a Workspace would, in the image, then ask the lesson's check whether the task is done; what it said, also kept in result."

	| value failed |
	code := aString.
	failed := nil.
	value := nil.
	"Read first, so a slip is said as a slip: a name the image doesn't know, or text that isn't Smalltalk."
	[[ Parser new parse: aString readStream class: UndefinedObject noPattern: true context: nil notifying: nil ifFail: [ nil ]]
		on: UndeclaredVariableWarning do: [ :w | failed := 'the image doesn''t know the name ', (w instVarNamed: 'name'), ' (a slip of the keys?)'. w resume: true ]]
		on: Error do: [ :ex | failed := 'that isn''t Smalltalk the image can read: ', (ex messageText ifNil: [ ex description ]) ].
	"Under a change set of the lessons' own: a class or a method made outside any would have Cuis ask for a change set's name in a dialog."
	failed ifNil: [
		[ ChangeSet installing: 'Lessons' do: [ value := Compiler evaluate: aString ]] on: Error, UndeclaredVariableWarning do: [ :ex |
			(ex isKindOf: Error) ifTrue: [ failed := 'that stopped with an error: ', ex description. nil ] ifFalse: [ ex resume: true ]]].
	result := failed
		ifNotNil: [ 'Not yet: ', failed ]
		ifNil: [
			([ (self lesson at: #check) value: value ] on: Error do: [ :ex | false ])
				ifTrue: [
					self class done add: index.
					'Done!! ', (index < self class lessons size ifTrue: [ 'Next takes you to lesson ', (index + 1) printString, '.' ] ifFalse: [ 'That was the last lesson.' ]) ]
				ifFalse: [ 'It answered ', (value printString ifEmpty: [ 'nothing' ]), ', which isn''t it yet. Hint shows the way.' ]].
	self changed: #titles; changed: #result.
	^ result! !

!VikixLessons methodsFor: 'checking' stamp: 'vikix 10/11/2026 10:00'!
hint
	"The Hint button."

	result := 'Hint: ', (self lesson at: #hint).
	self changed: #result! !

!VikixLessons methodsFor: 'checking' stamp: 'vikix 10/11/2026 10:00'!
next
	"The Next button."

	self index: index + 1! !

!VikixLessonsWindow methodsFor: 'building' stamp: 'vikix 10/11/2026 10:00'!
buildMorphicWindow

	| right buttons |
	list := PluggableListMorph withModel: model listGetter: #titles indexGetter: #index indexSetter: #index:.
	taskPane := TextModelMorph textProvider: model textGetter: #task.
	taskPane disableEditing; wrapFlag: true.
	codePane := TextModelMorph textProvider: model textGetter: #code textSetter: #code:.
	codePane acceptOnAny: true; wrapFlag: true.
	status := LabelMorph contents: ''.
	buttons := LinearLayoutMorph newRow.
	buttons gap: 6; padding: 4; color: self windowColor; doAdoptWidgetsColor.
	buttons
		addMorph: (PluggableButtonMorph model: model action: #check label: 'Check') proportionalWidth: 1;
		addMorph: (PluggableButtonMorph model: model action: #hint label: 'Hint') proportionalWidth: 1;
		addMorph: (PluggableButtonMorph model: model action: #next label: 'Next') proportionalWidth: 1.
	right := LinearLayoutMorph newColumn.
	right gap: 4; color: self windowColor; doAdoptWidgetsColor.
	right
		addMorph: taskPane proportionalHeight: 0.5;
		addMorph: codePane proportionalHeight: 0.5;
		addMorph: buttons fixedHeight: 30;
		addMorph: status fixedHeight: 20.
	self layoutMorph
		addMorph: list proportionalWidth: 0.3;
		addMorph: right proportionalWidth: 0.7.
	model addDependent: self! !

!VikixLessonsWindow methodsFor: 'building' stamp: 'vikix 10/11/2026 10:00'!
initialExtent

	^ 720 @ 480! !

!VikixLessonsWindow methodsFor: 'updating' stamp: 'vikix 10/11/2026 10:00'!
update: aSymbol
	"The model changed: the result's line, the lesson's panes."

	super update: aSymbol.
	aSymbol == #result ifTrue: [ status contents: model result ].
	aSymbol == #index ifTrue: [ list update: #titles ]! !

!VikixLessonsWindow methodsFor: 'accessing' stamp: 'vikix 10/11/2026 10:00'!
model

	^ model! !
