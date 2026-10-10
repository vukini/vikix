'From Cuis7.7 [latest update: #7977] on 10 October 2026 at 12:00:00 pm'!
'Description The desktop as objects: StumpWM''s workspaces and windows drawn as morphs in Cuis.

VikixDesktop open shows a window with a column a workspace and a box a window, as the desktop is now, asked of StumpWM once a second through its Swank door (127.0.0.1:4004, the same password as the Cuis door, ~/.slime-secret) with the Lisp function vikix-desktop-json, the one vikix mcp''s desktop tool reads. Read-only in this version: grab a morph, open its halo, inspect it (a VikixWindowMorph knows its window''s number, title, class and whether it has the focus); nothing is sent back to the desktop. Vikix''s part of Cuis: vikix cuis setup loads it (cuis/VikixDesktop.pck.st in the Vikix checkout).'!
!provides: 'VikixDesktop' 1 0!
!requires: 'JSON' 1 0 nil!
!requires: 'Network-Kernel' 1 12 nil!
!requires: 'VikixServer' 1 0 nil!
SystemOrganization addCategory: #'VikixDesktop'!


!classDefinition: #VikixSwank category: #'VikixDesktop'!
Object subclass: #VikixSwank
	instanceVariableNames: 'socket buffer'
	classVariableNames: 'Port'
	poolDictionaries: ''
	category: 'VikixDesktop'!
!classDefinition: 'VikixSwank class' category: #'VikixDesktop'!
VikixSwank class
	instanceVariableNames: ''!

!classDefinition: #VikixDesktop category: #'VikixDesktop'!
Object subclass: #VikixDesktop
	instanceVariableNames: 'latest error fetching'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixDesktop'!
!classDefinition: 'VikixDesktop class' category: #'VikixDesktop'!
VikixDesktop class
	instanceVariableNames: ''!

!classDefinition: #VikixDesktopWindow category: #'VikixDesktop'!
SystemWindow subclass: #VikixDesktopWindow
	instanceVariableNames: 'row status workspaces shown'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixDesktop'!
!classDefinition: 'VikixDesktopWindow class' category: #'VikixDesktop'!
VikixDesktopWindow class
	instanceVariableNames: ''!

!classDefinition: #VikixWorkspaceMorph category: #'VikixDesktop'!
LinearLayoutMorph subclass: #VikixWorkspaceMorph
	instanceVariableNames: 'number name current kind label windows'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixDesktop'!
!classDefinition: 'VikixWorkspaceMorph class' category: #'VikixDesktop'!
VikixWorkspaceMorph class
	instanceVariableNames: ''!

!classDefinition: #VikixWindowMorph category: #'VikixDesktop'!
ColoredBoxMorph subclass: #VikixWindowMorph
	instanceVariableNames: 'number title windowClass focused'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixDesktop'!
!classDefinition: 'VikixWindowMorph class' category: #'VikixDesktop'!
VikixWindowMorph class
	instanceVariableNames: ''!


!VikixSwank commentStamp: '<historical>' prior: 0!
A client of StumpWM's Swank, as vikix eval is: the password packet first, then one request evaluated by vikix-eval-for-agent in the window manager's main thread, and what it printed back. One connection a request. Port 4004 unless the launcher said another (VikixSwank port: N).!

!VikixDesktop commentStamp: '<historical>' prior: 0!
The model of the desktop window: asks StumpWM for the desktop (vikix-desktop-json) in a process of its own, so Morphic never waits on the window manager, and keeps the last answer, or why there is none.!

!VikixDesktopWindow commentStamp: '<historical>' prior: 0!
The window: a row of VikixWorkspaceMorphs, a line below saying where the desktop is read from, stepped each second to show the model's latest answer. Morphs are kept between answers (a workspace by its number, a window by its), so a halo opened on one stays.!

!VikixWorkspaceMorph commentStamp: '<historical>' prior: 0!
One workspace: a column with its number and name on top and a VikixWindowMorph a window. Inspect me for the workspace's number, name, kind (tiles, strip, floating) and whether it is the one in view.!

!VikixWindowMorph commentStamp: '<historical>' prior: 0!
One window of the desktop: its number, class and title drawn in a box, framed when it has the focus. Inspect me for those.!

!VikixSwank class methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
port
	"StumpWM's Swank: 4004, unless the launcher said another."

	^ Port ifNil: [ 4004 ]! !

!VikixSwank class methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
port: aNumber

	Port := aNumber! !

!VikixSwank class methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
secretPath
	"The password file, the one the Cuis door was given (~/.slime-secret); nil when the image was started without one."

	^ VikixServer current ifNotNil: [ :door | door secretPath ]! !

!VikixSwank class methodsFor: 'asking' stamp: 'vikix 10/10/2026 12:00'!
eval: lispText
	"What the Lisp printed, as a String, or an error."

	^ self new eval: lispText! !

!VikixSwank class methodsFor: 'asking' stamp: 'vikix 10/10/2026 12:00'!
desktop
	"The desktop as vikix-desktop-json gives it: a Dictionary with workspaces and screens."

	| printed |
	printed := self eval: '(vikix-desktop-json)'.
	^ Json readFrom: (self valueIn: printed) readStream! !

!VikixSwank class methodsFor: 'text' stamp: 'vikix 10/10/2026 12:00'!
lispString: aString
	"aString as a Lisp string literal."

	^ '"', ((aString copyReplaceAll: '\' with: '\\') copyReplaceAll: '"' with: '\"'), '"'! !

!VikixSwank class methodsFor: 'text' stamp: 'vikix 10/10/2026 12:00'!
lispStringsIn: aString
	"Every string literal in a Swank reply, in order, unescaped; a reply cut off inside a string gives what came of it."

	| strings i chars |
	strings := OrderedCollection new.
	i := 1.
	[ i <= aString size ] whileTrue: [
		(aString at: i) = $" ifTrue: [
			i := i + 1.
			chars := WriteStream on: String new.
			[ i <= aString size and: [ (aString at: i) ~= $" ]] whileTrue: [
				((aString at: i) = $\ and: [ i < aString size ]) ifTrue: [ i := i + 1 ].
				chars nextPut: (aString at: i).
				i := i + 1 ].
			strings add: chars contents ].
		i := i + 1 ].
	^ strings! !

!VikixSwank class methodsFor: 'text' stamp: 'vikix 10/10/2026 12:00'!
valueIn: printed
	"The value of the last form, from what vikix-eval-for-agent printed: the last line starting with => , a Lisp string unquoted."

	| value |
	value := nil.
	printed lines do: [ :line | (line beginsWith: '=> ') ifTrue: [ value := line copyFrom: 4 to: line size ]].
	value ifNil: [ ^ self error: 'StumpWM printed no value' ].
	(value size >= 2 and: [ value first = $" and: [ value last = $" ]]) ifFalse: [ ^ value ].
	^ (self lispStringsIn: value) first! !

!VikixSwank methodsFor: 'asking' stamp: 'vikix 10/10/2026 12:00'!
eval: lispText
	"One request: connect, the password, the forms through vikix-eval-for-agent; what they printed, or an error saying why not."

	| inner |
	self connect.
	[
		self sendPassword.
		inner := '(if (fboundp (quote stumpwm::vikix-eval-for-agent)) (stumpwm::vikix-eval-for-agent ',
			(self class lispString: lispText), ') :missing)'.
		self send: '(:emacs-rex (swank:eval-and-grab-output ', (self class lispString: inner), ') "STUMPWM" t 1)'.
		^ self answer
	] ensure: [ self close ]! !

!VikixSwank methodsFor: 'asking' stamp: 'vikix 10/10/2026 12:00'!
answer
	"Swank's messages until the return of our request; what the forms printed, or an error."

	| reply strings printed status |
	[ reply := self receive.
	  reply beginsWith: '(:return' ] whileFalse: [
		(reply beginsWith: '(:debug ') ifTrue: [ ^ self error: 'StumpWM: Swank failed' ]].
	(reply beginsWith: '(:return (:ok') ifFalse: [ ^ self error: 'StumpWM aborted the request' ].
	strings := self class lispStringsIn: reply.
	printed := strings isEmpty ifTrue: [ '' ] ifFalse: [ strings first ].
	status := strings size > 1 ifTrue: [ strings last ] ifFalse: [ '' ].
	status = ':OK' ifTrue: [ ^ printed ].
	status = ':MISSING' ifTrue: [ ^ self error: 'the running StumpWM has an older Vikix config: reload it (Super+m, Reload config)' ].
	^ self error: (printed withBlanksTrimmed ifEmpty: [ 'StumpWM answered ', status ])! !

!VikixSwank methodsFor: 'connection' stamp: 'vikix 10/10/2026 12:00'!
connect
	"The loopback address alone, five seconds."

	buffer := ByteArray new.
	socket := Socket newTCP.
	[ socket connectTo: #[127 0 0 1] port: self class port waitForConnectionFor: 5 ]
		on: Error
		do: [ :ex |
			self close.
			^ self error: 'nothing answers on 127.0.0.1:', self class port printString, ' (is StumpWM running with Vikix''s config?)' ]! !

!VikixSwank methodsFor: 'connection' stamp: 'vikix 10/10/2026 12:00'!
close

	socket ifNotNil: [ :s | s closeAndDestroy: 2 ].
	socket := nil! !

!VikixSwank methodsFor: 'connection' stamp: 'vikix 10/10/2026 12:00'!
sendPassword
	"The first line of the secret file, as a packet of its own, as SLIME sends it; without the file nothing is sent, and Swank without a secret takes anyone."

	| path secret |
	path := self class secretPath.
	path ifNil: [ ^ self ].
	secret := [ (FileEntry withAbsolutePathName: path) readStreamDo: [ :stream | stream nextLine ]] on: Error do: [ :ex | nil ].
	secret ifNotNil: [ self send: secret ]! !

!VikixSwank methodsFor: 'connection' stamp: 'vikix 10/10/2026 12:00'!
send: aString
	"A Swank packet: six hex digits of the UTF-8 length, then the text."

	| bytes |
	bytes := aString asUtf8Bytes.
	socket sendData: (bytes size printStringBase: 16 length: 6 padded: true) asUtf8Bytes.
	socket sendData: bytes! !

!VikixSwank methodsFor: 'connection' stamp: 'vikix 10/10/2026 12:00'!
receive
	"One Swank message, as a String: six hex digits of length, then the text."

	| length |
	length := Integer readFrom: (String fromUtf8Bytes: (self readBytes: 6)) asUppercase readStream base: 16.   "Swank writes the hex in capitals, vikix eval in small letters; Cuis reads only capitals"
	^ String fromUtf8Bytes: (self readBytes: length)! !

!VikixSwank methodsFor: 'connection' stamp: 'vikix 10/10/2026 12:00'!
readBytes: count
	"Exactly count bytes, waiting up to the deadline StumpWM's own evaluator keeps plus a little."

	| chunk got bytes |
	[ buffer size < count ] whileTrue: [
		socket waitForDataFor: 15
			ifClosed: [ ^ self error: 'StumpWM closed the connection' ]
			ifTimedOut: [ ^ self error: 'no answer from StumpWM in 15 seconds' ].
		chunk := ByteArray new: 65536.
		got := socket receiveAvailableDataInto: chunk.
		got = 0
			ifTrue: [ socket isConnected ifFalse: [ ^ self error: 'StumpWM closed the connection' ]]
			ifFalse: [ buffer := buffer, (chunk copyFrom: 1 to: got) ]].
	bytes := buffer copyFrom: 1 to: count.
	buffer := buffer copyFrom: count + 1 to: buffer size.
	^ bytes! !

!VikixDesktop class methodsFor: 'opening' stamp: 'vikix 10/10/2026 12:00'!
open
	"The desktop as objects, in a window: VikixDesktop open"

	^ VikixDesktopWindow open: self new label: 'Vikix desktop'! !

!VikixDesktop class methodsFor: 'opening' stamp: 'vikix 10/10/2026 12:00'!
window
	"The open desktop window, or nil."

	^ UISupervisor ui ifNotNil: [ :world |
		world submorphs detect: [ :m | m isKindOf: VikixDesktopWindow ] ifNone: [ nil ]]! !

!VikixDesktop class methodsFor: 'opening' stamp: 'vikix 10/10/2026 12:00'!
summary
	"What the open window shows, a line a morph: for vikix cuis status and the tests."

	^ self window ifNil: [ 'no desktop window' ] ifNotNil: [ :w | w summary ]! !

!VikixDesktop methodsFor: 'stepping' stamp: 'vikix 10/10/2026 12:00'!
wantsSteps

	^ true! !

!VikixDesktop methodsFor: 'stepping' stamp: 'vikix 10/10/2026 12:00'!
stepTime

	^ 1000! !

!VikixDesktop methodsFor: 'stepping' stamp: 'vikix 10/10/2026 12:00'!
stepAt: millisecondsSinceLast

	self fetch! !

!VikixDesktop methodsFor: 'stepping' stamp: 'vikix 10/10/2026 12:00'!
fetch
	"Ask StumpWM in a process of its own, one at a time; the window reads latest and error at its next step."

	fetching == true ifTrue: [ ^ self ].
	fetching := true.
	[[[ latest := VikixSwank desktop. error := nil ]
		on: Error do: [ :ex | error := ex description ]]
			ensure: [ fetching := false ]] forkNamed: 'VikixDesktop'! !

!VikixDesktop methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
latest
	"The desktop as last answered (a Dictionary), or nil."

	^ latest! !

!VikixDesktop methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
error
	"Why the last ask gave nothing, or nil."

	^ error! !

!VikixDesktopWindow methodsFor: 'building' stamp: 'vikix 10/10/2026 12:00'!
buildMorphicWindow

	row := LinearLayoutMorph newRow.
	row gap: 6; padding: 6; color: self windowColor; doAdoptWidgetsColor.
	status := LabelMorph contents: 'asking StumpWM...'.
	workspaces := Dictionary new.
	self layoutMorph
		addMorph: row proportionalHeight: 1;
		addMorph: status fixedHeight: 20! !

!VikixDesktopWindow methodsFor: 'building' stamp: 'vikix 10/10/2026 12:00'!
initialExtent

	^ 640 @ 400! !

!VikixDesktopWindow methodsFor: 'stepping' stamp: 'vikix 10/10/2026 12:00'!
stepTime

	^ 1000! !

!VikixDesktopWindow methodsFor: 'stepping' stamp: 'vikix 10/10/2026 12:00'!
step
	"The model's latest answer onto the morphs, when it is a new one."

	model latest ifNotNil: [ :desktop |
		desktop == shown ifFalse: [
			self show: desktop.
			shown := desktop ]].
	status contents: (model error ifNil: [
		'StumpWM on 127.0.0.1:', VikixSwank port printString, ', read every second' ])! !

!VikixDesktopWindow methodsFor: 'stepping' stamp: 'vikix 10/10/2026 12:00'!
show: aDictionary
	"A column a workspace, by number: kept where it is, made when new, removed when gone; put in the desktop's order when that changed."

	| seen order |
	seen := OrderedCollection new.
	(aDictionary at: 'workspaces') do: [ :each | | number column |
		number := each at: 'number'.
		seen add: number.
		column := workspaces at: number ifAbsent: [ nil ].
		column ifNil: [
			column := VikixWorkspaceMorph newColumn.
			workspaces at: number put: column ].
		column update: each ].
	(workspaces keys reject: [ :k | seen includes: k ]) do: [ :k |
		(workspaces at: k) delete.
		workspaces removeKey: k ].
	order := seen collect: [ :k | workspaces at: k ].
	row submorphs asArray = order asArray ifFalse: [
		row removeAllMorphs.
		order reverseDo: [ :column | row addMorph: column proportionalWidth: 1 ]]! !

!VikixDesktopWindow methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
summary
	"A line a morph: workspace NUMBER NAME [here] KIND, then its windows indented."

	^ String streamContents: [ :s |
		row submorphs do: [ :column | column summaryOn: s ].
		s nextPutAll: status contents ]! !

!VikixWorkspaceMorph methodsFor: 'updating' stamp: 'vikix 10/10/2026 12:00'!
update: aDictionary
	"The workspace as the desktop says it is: name, whether in view, and its windows by number."

	| seen order |
	number := aDictionary at: 'number'.
	name := aDictionary at: 'name'.
	current := aDictionary at: 'current'.
	kind := aDictionary at: 'kind'.
	windows ifNil: [ windows := Dictionary new ].
	label ifNil: [
		label := LabelMorph contents: ''.
		self addMorph: label fixedHeight: 20 ].
	label contents: number printString, ' ', name, (current ifTrue: [ ' (in view)' ] ifFalse: [ '' ]).
	self color: (current
		ifTrue: [ Theme current textHighlight ]
		ifFalse: [ Theme current paneBackgroundFrom: Theme current defaultWindowColor ]).
	seen := OrderedCollection new.
	(aDictionary at: 'windows') do: [ :each | | n box |
		n := each at: 'number'.
		seen add: n.
		box := windows at: n ifAbsent: [ nil ].
		box ifNil: [
			box := VikixWindowMorph new.
			windows at: n put: box ].
		box update: each ].
	(windows keys reject: [ :k | seen includes: k ]) do: [ :k |
		(windows at: k) delete.
		windows removeKey: k ].
	order := seen collect: [ :k | windows at: k ].
	(submorphs copyWithout: label) asArray = order asArray ifFalse: [
		order do: [ :box | box owner = self ifTrue: [ self removeMorph: box ]].
		order reverseDo: [ :box | self addMorph: box fixedHeight: 24 ].
		self removeMorph: label.
		self addMorph: label fixedHeight: 20 ]! !

!VikixWorkspaceMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
number

	^ number! !

!VikixWorkspaceMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
name

	^ name! !

!VikixWorkspaceMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
kind
	"tiles, strip or floating, as the desktop said."

	^ kind! !

!VikixWorkspaceMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
isCurrent
	"Whether this is the workspace in view."

	^ current == true! !

!VikixWorkspaceMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
windowMorphs
	"The windows' morphs, top to bottom."

	^ submorphs select: [ :m | m isKindOf: VikixWindowMorph ]! !

!VikixWorkspaceMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
summaryOn: aStream

	aStream nextPutAll: 'workspace ', number printString, ' ', name; nextPutAll: (self isCurrent ifTrue: [ ' here' ] ifFalse: [ '' ]); nextPutAll: ' ', kind; newLine.
	self windowMorphs do: [ :box | box summaryOn: aStream ]! !

!VikixWorkspaceMorph methodsFor: 'printing' stamp: 'vikix 10/10/2026 12:00'!
printOn: aStream

	super printOn: aStream.
	aStream nextPutAll: ' (workspace ', number printString, ' ', name, ')'! !

!VikixWindowMorph methodsFor: 'updating' stamp: 'vikix 10/10/2026 12:00'!
update: aDictionary
	"The window as the desktop says it is."

	number := aDictionary at: 'number'.
	title := aDictionary at: 'title'.
	windowClass := aDictionary at: 'class'.
	focused := aDictionary at: 'focused'.
	self color: (focused
		ifTrue: [ Theme current textHighlight ]
		ifFalse: [ Theme current textPane ]).
	self setBalloonText: title.
	self redrawNeeded! !

!VikixWindowMorph methodsFor: 'drawing' stamp: 'vikix 10/10/2026 12:00'!
drawOn: aCanvas

	super drawOn: aCanvas.
	aCanvas
		drawString: self line
		at: 4 @ 4
		font: Preferences standardListFont
		color: Theme current text.
	self hasFocus ifTrue: [
		aCanvas frameRectangle: self localBounds color: Theme current focusIndicator borderWidth: 2 borderStyleSymbol: #simple ]! !

!VikixWindowMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
line
	"NUMBER CLASS: TITLE"

	^ number printString, ' ', windowClass, ': ', title! !

!VikixWindowMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
number

	^ number! !

!VikixWindowMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
title

	^ title! !

!VikixWindowMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
windowClass

	^ windowClass! !

!VikixWindowMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
hasFocus
	"Whether the desktop's focus is on this window."

	^ focused == true! !

!VikixWindowMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
summaryOn: aStream

	aStream nextPutAll: '  window ', self line; nextPutAll: (self hasFocus ifTrue: [ ' focused' ] ifFalse: [ '' ]); newLine! !

!VikixWindowMorph methodsFor: 'printing' stamp: 'vikix 10/10/2026 12:00'!
printOn: aStream

	super printOn: aStream.
	aStream nextPutAll: ' (', self line, ')'! !
