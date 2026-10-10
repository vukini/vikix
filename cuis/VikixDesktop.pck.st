'From Cuis7.7 [latest update: #7977] on 10 October 2026 at 12:00:00 pm'!
'Description The desktop as objects: StumpWM''s workspaces and windows drawn as morphs in Cuis.

VikixDesktop open shows a window with the bar''s fields along the top, a column a workspace and a box a window, as the desktop is now, asked of StumpWM once a second through its Swank door (127.0.0.1:4004, the same password as the Cuis door, ~/.slime-secret) with the Lisp function vikix-desktop-json, the one vikix mcp''s desktop tool reads. The boxes act: drag one to another column and the real window moves there (StumpWM''s own move-window-to-group, sent through the same door), click one and its window takes the focus, click a column''s name and the desktop goes to that workspace. Nothing is guessed: what the window shows is what StumpWM answered at the last poll, so a move shows a moment after the drop. Halos and inspectors work on the morphs (a VikixWindowMorph knows its window''s number, title, class and whether it has the focus). Vikix''s part of Cuis: vikix cuis setup loads it (cuis/VikixDesktop.pck.st in the Vikix checkout).'!
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
	instanceVariableNames: 'latest error fetching said saidAt'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixDesktop'!
!classDefinition: 'VikixDesktop class' category: #'VikixDesktop'!
VikixDesktop class
	instanceVariableNames: ''!

!classDefinition: #VikixDesktopWindow category: #'VikixDesktop'!
SystemWindow subclass: #VikixDesktopWindow
	instanceVariableNames: 'row status workspaces shown bar'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixDesktop'!
!classDefinition: 'VikixDesktopWindow class' category: #'VikixDesktop'!
VikixDesktopWindow class
	instanceVariableNames: ''!

!classDefinition: #VikixWorkspaceMorph category: #'VikixDesktop'!
LinearLayoutMorph subclass: #VikixWorkspaceMorph
	instanceVariableNames: 'number name current kind label windows desktop'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixDesktop'!
!classDefinition: 'VikixWorkspaceMorph class' category: #'VikixDesktop'!
VikixWorkspaceMorph class
	instanceVariableNames: ''!

!classDefinition: #VikixWindowMorph category: #'VikixDesktop'!
ColoredBoxMorph subclass: #VikixWindowMorph
	instanceVariableNames: 'number title windowClass focused workspace'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixDesktop'!
!classDefinition: 'VikixWindowMorph class' category: #'VikixDesktop'!
VikixWindowMorph class
	instanceVariableNames: ''!


!VikixSwank commentStamp: '<historical>' prior: 0!
A client of StumpWM's Swank, as vikix eval is: the password packet first, then one request evaluated by vikix-eval-for-agent in the window manager's main thread, and what it printed back. One connection a request. Port 4004 unless the launcher said another (VikixSwank port: N). The reads (desktop) and the acts (moveWindow:from:to:, focusWindow:on:, switchTo:) go the same road; an act's form uses StumpWM's own functions and answers a word, moved, focused, switched, or why not.!

!VikixDesktop commentStamp: '<historical>' prior: 0!
The model of the desktop window: asks StumpWM for the desktop (vikix-desktop-json) in a process of its own, so Morphic never waits on the window manager, and keeps the last answer, or why there is none. The acts (moveWindow:from:to:, focusWindow:on:, switchTo:) run the same way, one process each, say what StumpWM answered for a few seconds (said), and ask for the desktop again right after, so what shows is what StumpWM did.!

!VikixDesktopWindow commentStamp: '<historical>' prior: 0!
The window: the bar's fields along the top, a row of VikixWorkspaceMorphs, a line below saying where the desktop is read from or what the last act did, stepped each second to show the model's latest answer. Morphs are kept between answers (a workspace by its number, a window by its), so a halo opened on one stays.!

!VikixWorkspaceMorph commentStamp: '<historical>' prior: 0!
One workspace: a column with its number and name on top and a VikixWindowMorph a window. Inspect me for the workspace's number, name, kind (tiles, strip, floating) and whether it is the one in view. A VikixWindowMorph dropped on me moves its window here; a click on me goes to this workspace.!

!VikixWindowMorph commentStamp: '<historical>' prior: 0!
One window of the desktop: its number, class and title drawn in a box, framed when it has the focus. Inspect me for those. Press and drag me to another column to move the window there; click me and the window takes the focus.!

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

!VikixSwank class methodsFor: 'acting' stamp: 'vikix 10/10/2026 18:00'!
moveWindow: aNumber from: fromName to: toName
	"The real window aNumber of the workspace fromName onto the workspace toName, through StumpWM's own move-window-to-group; moved, or why not."

	^ self valueIn: (self eval: '(let* ((from (find-group (current-screen) ', (self lispString: fromName),
		')) (to (find-group (current-screen) ', (self lispString: toName),
		')) (w (and from (find ', aNumber printString, ' (group-windows from) :key (function window-number)))))',
		' (cond ((null to) "no such workspace") ((null w) "no such window") (t (move-window-to-group w to) "moved")))')! !

!VikixSwank class methodsFor: 'acting' stamp: 'vikix 10/10/2026 18:00'!
focusWindow: aNumber on: workspaceName
	"The focus onto the window aNumber of that workspace, the desktop going there; focused, or why not."

	^ self valueIn: (self eval: '(let* ((g (find-group (current-screen) ', (self lispString: workspaceName),
		')) (w (and g (find ', aNumber printString, ' (group-windows g) :key (function window-number)))))',
		' (cond ((null g) "no such workspace") ((null w) "no such window") (t (switch-to-group g) (focus-all w) "focused")))')! !

!VikixSwank class methodsFor: 'acting' stamp: 'vikix 10/10/2026 18:00'!
switchTo: workspaceName
	"The desktop onto that workspace; switched, or why not."

	^ self valueIn: (self eval: '(let ((g (find-group (current-screen) ', (self lispString: workspaceName),
		'))) (if g (progn (switch-to-group g) "switched") "no such workspace"))')! !

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

!VikixDesktop methodsFor: 'acting' stamp: 'vikix 10/10/2026 18:00'!
act: aBlock
	"One act on the desktop, in a process of its own: aBlock answers what to say (StumpWM's word, or an error's words), said for a few seconds; then the desktop is asked again, so what shows is what StumpWM did, never a guess."

	[[ self say: aBlock value ] on: Error do: [ :ex | self say: 'StumpWM: ', ex description ].
	 self fetch ] forkNamed: 'VikixDesktop act'! !

!VikixDesktop methodsFor: 'acting' stamp: 'vikix 10/10/2026 18:00'!
moveWindow: aNumber from: fromName to: toName
	"The real window onto another workspace: a box dropped on a column. The same column is nothing."

	fromName = toName ifTrue: [ ^ self ].
	self act: [ | answer |
		answer := VikixSwank moveWindow: aNumber from: fromName to: toName.
		answer = 'moved'
			ifTrue: [ 'moved window ', aNumber printString, ' to ', toName ]
			ifFalse: [ 'StumpWM: ', answer ]]! !

!VikixDesktop methodsFor: 'acting' stamp: 'vikix 10/10/2026 18:00'!
focusWindow: aNumber on: workspaceName
	"The focus onto a window: a box clicked."

	self act: [ | answer |
		answer := VikixSwank focusWindow: aNumber on: workspaceName.
		answer = 'focused'
			ifTrue: [ 'window ', aNumber printString, ' on ', workspaceName, ' has the focus' ]
			ifFalse: [ 'StumpWM: ', answer ]]! !

!VikixDesktop methodsFor: 'acting' stamp: 'vikix 10/10/2026 18:00'!
switchTo: workspaceName
	"The desktop onto a workspace: a column clicked."

	self act: [ | answer |
		answer := VikixSwank switchTo: workspaceName.
		answer = 'switched'
			ifTrue: [ 'on workspace ', workspaceName ]
			ifFalse: [ 'StumpWM: ', answer ]]! !

!VikixDesktop methodsFor: 'acting' stamp: 'vikix 10/10/2026 18:00'!
say: aString
	"What the last act did, for the window's status line."

	said := aString.
	saidAt := Time millisecondClockValue! !

!VikixDesktop methodsFor: 'accessing' stamp: 'vikix 10/10/2026 18:00'!
said
	"What the last act did, while it is recent (four seconds), or nil."

	^ (said notNil and: [ Time millisecondClockValue - saidAt < 4000 ]) ifTrue: [ said ] ifFalse: [ nil ]! !

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

	bar := LabelMorph contents: ''.
	row := LinearLayoutMorph newRow.
	row gap: 6; padding: 6; color: self windowColor; doAdoptWidgetsColor.
	status := LabelMorph contents: 'asking StumpWM...'.
	workspaces := Dictionary new.
	self layoutMorph
		addMorph: bar fixedHeight: 20;
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
	status contents: (model said ifNil: [ model error ifNil: [
		'StumpWM on 127.0.0.1:', VikixSwank port printString, ', read every second' ]])! !

!VikixDesktopWindow methodsFor: 'stepping' stamp: 'vikix 10/10/2026 12:00'!
show: aDictionary
	"A column a workspace, by number: kept where it is, made when new, removed when gone; put in the desktop's order when that changed."

	| seen order |
	bar contents: (self barLine: (aDictionary at: 'bar' ifAbsent: [ #() ])).
	seen := OrderedCollection new.
	(aDictionary at: 'workspaces') do: [ :each | | number column |
		number := each at: 'number'.
		seen add: number.
		column := workspaces at: number ifAbsent: [ nil ].
		column ifNil: [
			column := VikixWorkspaceMorph newColumn.
			column desktop: model.
			workspaces at: number put: column ].
		column update: each ].
	(workspaces keys reject: [ :k | seen includes: k ]) do: [ :k |
		(workspaces at: k) delete.
		workspaces removeKey: k ].
	order := seen collect: [ :k | workspaces at: k ].
	row submorphs asArray = order asArray ifFalse: [
		row removeAllMorphs.
		order reverseDo: [ :column | row addMorph: column proportionalWidth: 1 ]]! !

!VikixDesktopWindow methodsFor: 'stepping' stamp: 'vikix 10/10/2026 18:00'!
barLine: fields
	"The bar's fields as one line: FIELD SHOWS, a dot between; nothing from a desktop that sends none."

	^ String streamContents: [ :s |
		fields
			do: [ :each | s nextPutAll: (each at: 'field'); space; nextPutAll: (each at: 'shows') ]
			separatedBy: [ s nextPutAll: '  ·  ' ]]! !

!VikixDesktopWindow methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
summary
	"A line a morph: bar FIELD SHOWS ... when the bar shows anything, workspace NUMBER NAME [here] KIND, then its windows indented, and the status line last."

	^ String streamContents: [ :s |
		bar contents isEmpty ifFalse: [ s nextPutAll: 'bar '; nextPutAll: bar contents; newLine ].
		row submorphs do: [ :column | column summaryOn: s ].
		s nextPutAll: status contents ]! !

!VikixDesktopWindow methodsFor: 'accessing' stamp: 'vikix 10/10/2026 18:00'!
workspaceNumbered: aNumber
	"The column of that workspace, or nil."

	^ workspaces at: aNumber ifAbsent: [ nil ]! !

!VikixDesktopWindow methodsFor: 'accessing' stamp: 'vikix 10/10/2026 18:00'!
windowNumbered: aNumber on: workspaceNumber
	"The box of that window on that workspace, or nil."

	^ (self workspaceNumbered: workspaceNumber) ifNotNil: [ :column | column windowNumbered: aNumber ]! !

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
		box workspace: self.
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

!VikixWorkspaceMorph methodsFor: 'dropping' stamp: 'vikix 10/10/2026 18:00'!
allowsMorphDrop
	"A box may be dropped on me."

	^ true! !

!VikixWorkspaceMorph methodsFor: 'dropping' stamp: 'vikix 10/10/2026 18:00'!
wantsDroppedMorph: aMorph event: anEvent
	"A window's box, nothing else."

	^ aMorph isKindOf: VikixWindowMorph! !

!VikixWorkspaceMorph methodsFor: 'dropping' stamp: 'vikix 10/10/2026 18:00'!
acceptDroppingMorph: aBox event: anEvent
	"A box dropped on me: its real window goes to this workspace. The box goes back into the column it came from for now, and the next poll draws it where StumpWM put it."

	aBox workspace ifNotNil: [ :from | from addMorph: aBox fixedHeight: 24 ].
	aBox droppedOn: self! !

!VikixWorkspaceMorph methodsFor: 'events' stamp: 'vikix 10/10/2026 18:00'!
handlesMouseDown: aMouseButtonEvent

	^ true! !

!VikixWorkspaceMorph methodsFor: 'events' stamp: 'vikix 10/10/2026 18:00'!
mouseButton1Down: aMouseButtonEvent localPosition: localEventPosition
	"A click goes to this workspace; a drag of the column itself is nothing."

	aMouseButtonEvent hand
		waitForClicksOrDrag: self event: aMouseButtonEvent
		dragSel: #dragEvent:localPosition: clkSel: #click:localPosition:! !

!VikixWorkspaceMorph methodsFor: 'events' stamp: 'vikix 10/10/2026 18:00'!
dragEvent: aMouseEvent localPosition: aPoint
	"The column stays where it is."! !

!VikixWorkspaceMorph methodsFor: 'events' stamp: 'vikix 10/10/2026 18:00'!
click: aMouseButtonEvent localPosition: localEventPosition
	"The desktop goes to this workspace."

	desktop ifNotNil: [ :d | d switchTo: name ]! !

!VikixWorkspaceMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 18:00'!
desktop
	"The model, which the acts go through."

	^ desktop! !

!VikixWorkspaceMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 18:00'!
desktop: aVikixDesktop

	desktop := aVikixDesktop! !

!VikixWorkspaceMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 18:00'!
windowNumbered: aNumber
	"The box of that window, or nil."

	^ windows ifNotNil: [ :boxes | boxes at: aNumber ifAbsent: [ nil ]]! !

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

!VikixWindowMorph methodsFor: 'events' stamp: 'vikix 10/10/2026 18:00'!
handlesMouseDown: aMouseButtonEvent

	^ true! !

!VikixWindowMorph methodsFor: 'events' stamp: 'vikix 10/10/2026 18:00'!
mouseButton1Down: aMouseButtonEvent localPosition: localEventPosition
	"A click focuses the window; a drag takes the box to another column (Morph's own dragEvent:localPosition: puts it in the hand)."

	aMouseButtonEvent hand
		waitForClicksOrDrag: self event: aMouseButtonEvent
		dragSel: #dragEvent:localPosition: clkSel: #click:localPosition:! !

!VikixWindowMorph methodsFor: 'events' stamp: 'vikix 10/10/2026 18:00'!
click: aMouseButtonEvent localPosition: localEventPosition
	"The real window takes the focus."

	workspace ifNotNil: [ :ws | ws desktop ifNotNil: [ :d | d focusWindow: number on: ws name ]]! !

!VikixWindowMorph methodsFor: 'events' stamp: 'vikix 10/10/2026 18:00'!
droppedOn: aColumn
	"Dropped on a column: the real window goes to that workspace, from the one this box was drawn under at the last poll."

	workspace ifNotNil: [ :from |
		aColumn desktop ifNotNil: [ :d | d moveWindow: number from: from name to: aColumn name ]]! !

!VikixWindowMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 18:00'!
workspace
	"The column this box was drawn under at the last poll."

	^ workspace! !

!VikixWindowMorph methodsFor: 'accessing' stamp: 'vikix 10/10/2026 18:00'!
workspace: aVikixWorkspaceMorph

	workspace := aVikixWorkspaceMorph! !

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
