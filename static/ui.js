var xhttp = new XMLHttpRequest();
var domain;
var board;

function loadBoard(thisDomain, thisBoard) {
    domain = thisDomain;
    board = thisBoard;
    loadJSON("/api/v1/boards/" + domain + "/" + board, initBoard);
}

function loadJSON(url, callback) {
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
            //alert(this.responseText);
            callback(JSON.parse(this.responseText));
        }
        else {
            // XXX error
//            alert("failed getting json for " + url + ": " + this.readyState + " " + this.status);
        }
    };
    xhttp.open("GET", url, true);
    xhttp.send();
}

function initBoard(data) {
    var boardContainer = document.getElementById("boardContainer");
    var content = data.content;
    // XXX refactor to avoid switch and improve recursion
    switch(content.type) {
        case 'sorted-board':
            makeSortedBoard(boardContainer, content);
            break;
        default:
            // XXX better error handling
            //alert("unknown case " + content.type + " in initBoard switch");
    }
}

function makeSortedBoard(container, spec) {
    //alert("makeSortedBoard "+ spec.id);
    var treeDiv = document.createElement('div');
    // XXX is the id really DOM-unique? may need prefixing or proper allocation scheme
    treeDiv.id = spec.id;
    treeDiv.className = 'sortedBoard';
    container.appendChild(treeDiv);
    // XXX put stuff into treeDiv
    // XXX domain should be overridable from spec
    loadJSON("/api/v1/sorted/" + domain + "/" + spec.sorting, function(content) {
            populateSortedTree(treeDiv, content, 0);
        });
}

// XXX determine depth, start hor/vert depending on that, recurse
function populateSortedTree(parentContainer, spec, orientation) {
    //alert("populateSortedTree");
    var hcont = makeHContainer("hcontainer", "Swimlane");
    parentContainer.appendChild(hcont);
    var children = spec.children;
    alert(JSON.stringify(spec));
    for (var i = 0; i < children.length; i++) {
        if (i > 0) {
            hcont.appendChild(makeVertHr());
        }
        var cell = makeCell("cell-" + children[i].nid + "-" + i, 2, children[i].nid);
        hcont.appendChild(cell);
        for (var j = 0; j < children[i].items.length; j++) {
            var item = children[i].items[j];
            cell.children[1].appendChild(makeSticker(item.title));
        }
        fixCellBreaks(cell.children[1]);
        
/*        childDiv = document.createElement('div');
        childDiv.id = children[i].nid; // XXX unique
        childDiv.className = 'sortedTreeCell';
        parentContainer.appendChild(childDiv);
        childDiv.innerHTML = JSON.stringify(children[i]);*/
    }
}

// ------------- from uitest -------------

/*document.addEventListener('DOMContentLoaded', init);

function init() {
    var grid = document.getElementById("sortGrid1");
    var vContainer = makeVContainer()
    grid.appendChild(vContainer);
    for (var j = 1; j <= 2; j++) {
        if (j > 1) {
            vContainer.appendChild(makeHorHr());
        }
        var hcontainer = makeHContainer("hcontainer"+j, "Swimlane");
        vContainer.appendChild(hcontainer);
        for (var i = 1; i <= 3; i++) {
            if (i > 1) {
                hcontainer.appendChild(makeVertHr());
            }
            var headerText = "";
            if (j == 1) {
                headerText = "Cell #" + i + " " + j;
            }
            hcontainer.appendChild(makeCell("cell-" + j + "-" + i, i, headerText));
        }
    }
    var start_cell = document.getElementById("cell-1-1")
    for (var i = 1; i < 6; i++) {
        appendSticker(start_cell, makeSticker("sticker-" + i));
    }
    fixCellBreaks(start_cell);
}

function appendSticker(cell, sticker) {
    cell.appendChild(sticker);
}*/

function fixCellBreaks(cell) {
    var cols = cell.getAttribute("x_width");
    log("fixCellBreaks " + cell.id + " to " + cols);
    var i = 0;
    var child = cell.firstChild;
    while (child) {
        var nextChild = child.nextSibling;
        if ((child.className == "sticker") || (child.className == "ghostSticker")) {
            log("&nbsp;&nbsp;" + child.id);
            if (child.style.display != "none") {
                if (((i % cols) == 0) && (i != 0)) {
                    log("&nbsp;&nbsp;&nbsp;&nbsp;break before");
                    cell.insertBefore(document.createElement("br"), child);
                }
                else {
                    log("&nbsp;&nbsp;&nbsp;&nbsp; no break due to position " + (i % cols));
                }
                i++;
            }
            else {
                log("&nbsp;&nbsp;&nbsp;&nbsp; no break due to display " + child.style.display);
            }
        }
        else {
            cell.removeChild(child);
        }
        child = nextChild;
    }
}

function makeVContainer() {
    var result = document.createElement("div");
    result.className = "vcontainer";
    return result;
}

function makeHContainer(id, title) {
    var result = document.createElement("div");
    result.className = "hcontainer";
    result.id = id;
    var header = document.createElement("div");
    header.className = "hcontainerHeader";
    var headerSpan = document.createElement("h1");
    headerSpan.innerHTML = title;
    header.appendChild(headerSpan);
    result.appendChild(header);
    return result;
}

function makeVertHr() {
    var result = document.createElement("hr");
    result.className = "vertical";
    return result;
}

function makeHorHr() {
    var result = document.createElement("hr");
    result.className = "horizontal";
    return result;
}

function makeHeader(title) {
    var result = document.createElement("div");
    result.className = "cellHeader";
    result.innerHTML = title;
    return result;
}

function makeCell(id, width, headerText) {
    var outer = document.createElement("div");
    outer.className = "cellOuter";
    outer.addEventListener("dragover", allowDrop);
    outer.addEventListener("drop", do_drop);
    outer.addEventListener("dragenter", enter_drop);
    outer.addEventListener("dragleave", leave_drop);
    outer.draggable = true;
    if (headerText) {
        var header = document.createElement("div");
        header.className = "cellHeader";
        header.innerHTML = headerText;
        outer.appendChild(header);
    }
    var result = document.createElement("div");
    result.className = "cell";
    result.id = id;
    result.addEventListener("dragover", allowDrop);
    result.addEventListener("drop", do_drop);
    result.addEventListener("dragenter", enter_drop);
    result.addEventListener("dragleave", leave_drop);
    result.draggable = true;
    result.setAttribute("x_width", width);
    result.style.minWidth = "" + (10.8*width+.33) + "em";
    outer.appendChild(result);
    return outer;
}

function makeSticker(id) {
    var result = document.createElement("div");
    result.className = "sticker";
    result.id = id;
    result.innerHTML = "<p>" + id + "</p>";
    result.addEventListener("dblclick", dbl_click);
    result.addEventListener("dragstart", start_drag);
    result.addEventListener("dragend", end_drag);
    result.addEventListener("dragenter", enter_drop);
    result.addEventListener("dragleave", leave_drop);
    result.draggable = true;
    return result;
}

function log(text) {
/*    var lines = document.getElementById("log").innerHTML.split('\n');
    var start = 0;
    var end = lines.length;
    if (end > 15) {
        start += end - 15;
    }
    var result = "";
    for (var i = start; i < end; i++) {
        result += lines[i] + "\n";
    }
    result += text + "<br/>\n";
    document.getElementById("log").innerHTML = result;*/
}

function fixContainerHeight(cont) {
/*
    log("fixContainerHeight " + cont.id);
    var maxHeight = 0;
    for (var i = 1; i < cont.childNodes.length; i++) {
        var cell = cont.childNodes[i];
        var height = cell.getBoundingClientRect().height;
        var style = cell.currentStyle || window.getComputedStyle(cell);
        var margin = parseInt(style.marginTop.slice(0, -2)) 
                    + parseInt(style.marginBottom.slice(0, -2));
        log("?? " + margin);
        if ((cell.className == "cell") && (height > maxHeight)) {
            maxHeight = cell.clientHeight;
        }
    }
    log("  maxHeight is " + maxHeight);
    for (var i = 1; i < cont.childNodes.length; i++) {
        var cell = cont.childNodes[i];
        if (cell.className == "cell") {
            cell.style.minHeight = (maxHeight - margin) + "px";
        }
    }*/
}

var draggedElement = null

var stickerMoved;
var draggedFrom;

function start_drag(ev) {
    ev.dataTransfer.setData("id", ev.target.id);
    ev.target.style.opacity = "0.5"; 
    ev.target.style.display = "none"; 
    draggedElement = ev.target;
    ev.target.parentNode.insertBefore(makeGhostSticker(ev.target), ev.target);
    draggedFrom = ev.target.parentNode;
    stickerMoved = false;
    log("starting drag");
}

function end_drag(ev) {
    var data = ev.dataTransfer.getData("id");
    clearGhostSticker();
    document.getElementById(data).style.opacity = "1";
    ev.target.style.display = "inline-block"; 
    draggedElement = null;
    //if (stickerMoved) {
        var draggedTo = document.getElementById(data).parentNode;
        fixCellBreaks(draggedTo);
        fixContainerHeight(draggedTo.parentNode);
        if (draggedFrom != draggedTo) {
            fixCellBreaks(draggedFrom);
            fixContainerHeight(draggedFrom.parentNode);
        }
    //}
    log("end drag");
}

function dbl_click(ev) {
    log("dbl_click " + ev.target.id);
}

var currentGhostSticker = null;

function makeGhostSticker(original) {
    clearGhostSticker();
    var result = document.createElement("div");
    result.className = "ghostSticker";
    result.innerHTML = original.innerHTML;
    result.id = "ghost";
    result.addEventListener("dragover", allowDrop);
    result.addEventListener("dragenter", enter_drop);
    result.addEventListener("dragleave", leave_drop);
    result.addEventListener("drop", do_drop);
    currentGhostSticker = result;
    return result;
}

function clearGhostSticker() {
    if ((currentGhostSticker != null) && (currentGhostSticker.parentNode != null)) {
        currentGhostSticker.parentNode.removeChild(currentGhostSticker);
        currentGhostSticker = null;
    }
}

function rowOrderPredicate(x, y, item) {
    var box = item.getBoundingClientRect();
    if (y < box.top) {
        return 0;
    }
    else if (y > box.bottom) {
        return 1;
    }
    else {
        if (item.parentNode.getAttribute("x_width") == "1") {
            var mid = (box.top + box.bottom) / 2;
            if (y < mid) {
                return 0;
            }
        }
        else
        {
            var mid = (box.left + box.right) / 2;
            if (x < mid) {
                return 0;
            }
        }
        return 1;
    }
}

function allowDrop(ev) {
    var target;
    log("allow " + ev.target.id);
    if (ev.target.className == "cell") {
        target = ev.target;
    }
    else if (ev.target.className == "cellOuter") {
        log("&nbsp;is outer");
        for (var i = 0; i < ev.target.childNodes.length; i++) {
            var child = ev.target.childNodes[i];
            if (child.className == "cell") {
                log("&nbsp;got child");
                target = child;
                break;
            }
        }
    }
    else if (ev.target.className == "sticker") {
        target = ev.target.parentNode;
    }
    else if (ev.target.className == "ghostSticker") {
        target = ev.target.parentNode;
    }
    else {
        return;
    }

    ev.preventDefault();
    ev.stopPropagation();
    var children = Array.prototype.slice.call(target.childNodes)
                        .filter(function(c) { 
                                return (( c.className == "sticker")
                                        && (c.id != draggedElement.id));
                            });
    var lo = -1;
    var hi = children.length;
    while ((hi - lo) > 1) {
        var pivot = Math.floor((lo + hi) / 2);
        var order = rowOrderPredicate(ev.clientX, ev.clientY, children[pivot]);
        if (order) {
            log("  pivot is " + children[pivot].id + " -> lo");
            lo = pivot;
        }
        else {
            log("  pivot is " + children[pivot].id + " -> hi");
            hi = pivot;
        }
    }
    var anchor;
    if (lo == -1) {
        anchor = children[0];
    }
    else {
        anchor = children[lo+1];
    }
    if (anchor) {
        log("anchor is " + anchor.id);
        if ((currentGhostSticker == null) || (currentGhostSticker.nextSibling != anchor)) {
            var prevGhostParent;
            if (currentGhostSticker) {
                prevGhostParent = currentGhostSticker.parentNode;
            }
            target.insertBefore(
                makeGhostSticker(draggedElement),
                anchor);
            fixCellBreaks(target); 
            if (target != prevGhostParent) {
                fixCellBreaks(prevGhostParent); 
            }
        }
    }
    else {
        log("anchor is null");
        if ((currentGhostSticker == null) || (currentGhostSticker.parentNode != target)
                || (currentGhostSticker.nextSibling != null)) {
            var prevGhostParent;
            if (currentGhostSticker) {
                prevGhostParent = currentGhostSticker.parentNode;
            }
            target.appendChild(makeGhostSticker(draggedElement));
            fixCellBreaks(target); 
            if (target != prevGhostParent) {
                fixCellBreaks(prevGhostParent); 
            }
        }
    }
}

var highlighted = null;
var highlight_count = 0;

function enter_drop(ev) {
    var target;
    log("enter " + ev.target.id);
    if (ev.target.className == "cell") {
        target = ev.target;
    }
    else if (ev.target.className == "cellHeader") {
    }
    else if (ev.target.className == "cellOuter") {
        for (var i = 0; i < ev.target.childNodes.length; i++) {
            var child = ev.target.childNodes[i];
            if (child.className == "cell") {
                target = child;
                break;
            }
        }
    }
    else if (ev.target.className == "sticker") {
        target = ev.target.parentNode;
    }
    else if (ev.target.className == "ghostSticker") {
        target = ev.target.parentNode;
    }
    else {
        return;
    }
    
    ev.preventDefault();
    ev.stopPropagation();

    if ((highlighted != null) && (highlighted != target)) {
//        highlighted.style.border = "1pt solid black";
        highlight_count = 0;
    }
    else if ((highlighted != null) && (highlighted == target)) {
        highlight_count++;
        return;
    }
    else {
        //target.style.border = "1pt dotted red";
        highlighted = target;
        highlight_count = 1;
    }
}

function leave_drop(ev) {
    log("leave " + ev.target.id);
    var target;
    if (ev.target.className == "cell") {
        target = ev.target;
    }
    else if (ev.target.className == "cellOuter") {
        for (var i = 0; i < ev.target.childNodes.length; i++) {
            var child = ev.target.childNodes[i];
            if (child.className == "cell") {
                target = child;
                break;
            }
        }
    }
    else if (ev.target.className == "sticker") {
        target = ev.target.parentNode;
    }
    else if (ev.target.className == "ghostSticker") {
        target = ev.target.parentNode;
    }
    else {
        return;
    }

    ev.preventDefault();
    ev.stopPropagation();

    highlight_count--;
    if (highlight_count == 0) {
        //target.style.border = "1pt solid black";
        highlighted = null;
        // we also need to reset the ghost position and parent to where it was when we started
        // the drag
    }
}

function do_drop(ev) {
    log("do_drop1 " + ev.target.id);
    var target;
    if (ev.target.className == "cell") {
        target = ev.target;
    }
    else if (ev.target.className == "cellOuter") {
        for (var i = 0; i < ev.target.childNodes.length; i++) {
            var child = ev.target.childNodes[i];
            if (child.className == "cell") {
                target = child;
                break;
            }
        }
    }
    else if (ev.target.className == "sticker") {
        target = ev.target.parentNode;
    }
    else if (ev.target.className == "ghostSticker") {
        target = ev.target.parentNode;
    }
    else {
        return;
    }

    ev.preventDefault();
    ev.stopPropagation();
    log("do_drop " + target.id);
    var data = ev.dataTransfer.getData("id");
    target.insertBefore(document.getElementById(data), currentGhostSticker);
    //target.style.border = "1pt solid black";
    highlighted = null;
    highlighted_count = 0;
    stickerMoved = true;
}
