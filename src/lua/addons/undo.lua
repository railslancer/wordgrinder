--!nonstrict
-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local STACKSIZE = 500

local function shallowequals(t1, t2)
	if (#t1 ~= #t2) then
		return false
	end

	for i = 1, #t1 do
		if (t1[i] ~= t2[i]) then
			return false
		end
	end

	return true
end

local function shallowcopy(t1)
	local t2 = {}
	for k, v in ipairs(t1) do
		t2[k] = v
	end
	return t2
end

local function savedocument()
	local copy = shallowcopy(currentDocument)
	copy.cp, copy.cw, copy.co = currentDocument.cp, currentDocument.cw, currentDocument.co
	return copy
end

local function loaddocument(copy)
	local oldlen = #currentDocument
	for i = 1, #copy do
		currentDocument[i] = copy[i]
	end
	for i = #copy+1, oldlen do
		currentDocument[i] = nil
	end
	currentDocument.cp, currentDocument.cw, currentDocument.co = copy.cp, copy.cw, copy.co
	currentDocument.mp = nil
	currentDocument:purge()
	QueueRedraw()
end

local function movechange(srcstack, deststack)
	local top = srcstack[1]
	if not top then
		return false
	end
	table.remove(srcstack, 1)

	table.insert(deststack, 1, savedocument())

	loaddocument(top)
	return true
end

-----------------------------------------------------------------------------
-- Commit an undo checkpoint

function Cmd.Checkpoint()
	local undostack = currentDocument._undostack or {}
	currentDocument._undostack = undostack

	local top = undostack[1]
	if not top or not shallowequals(currentDocument, top) then
		local copy = savedocument()
		table.insert(undostack, 1, copy)
		undostack[STACKSIZE] = nil

		-- Nuke the redo stack.
		currentDocument._redostack = {}
	end
	
	return true
end

-----------------------------------------------------------------------------
-- Undo a change.

function Cmd.Undo()
	currentDocument._undostack = currentDocument._undostack or {}
	currentDocument._redostack = currentDocument._redostack or {}
	if not movechange(currentDocument._undostack, currentDocument._redostack) then
		NonmodalMessage("Nothing left to undo")
		return false
	end
	NonmodalMessage("Undone ("..#currentDocument._undostack.." left in undo buffer)")
	return true
end

-----------------------------------------------------------------------------
-- Redo an undone change.

function Cmd.Redo()
	currentDocument._undostack = currentDocument._undostack or {}
	currentDocument._redostack = currentDocument._redostack or {}
	if not movechange(currentDocument._redostack, currentDocument._undostack) then
		NonmodalMessage("Nothing left to redo")
		return false
	end
	NonmodalMessage("Redone ("..#currentDocument._redostack.." left in redo buffer)")
	return true
end

