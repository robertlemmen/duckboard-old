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
        case 'sorted-tree':
            makeSortedTree(boardContainer, content);
            break;
        default:
            // XXX better error handling
            alert("unknown case in initBoard switch");
    }
}

function makeSortedTree(container, spec) {
    var treeDiv = document.createElement('div');
    // XXX is the id really DOM-unique? may need prefixing or proper allocation scheme
    treeDiv.id = spec.id;
    treeDiv.className = 'sortedTree';
    container.appendChild(treeDiv);
    // XXX put stuff into treeDiv
    // XXX domain should be overridable from spec
    loadJSON("/api/v1/sorted/" + domain + "/" + spec.id, function(content) {
            populateSortedTree(treeDiv, content, 0);
        });
}

function populateSortedTree(parentContainer, spec, orientation) {
    var children = spec.children;
    for (var i = 0; i < children.length; i++) {
        childDiv = document.createElement('div');
        childDiv.id = children[i].nid; // XXX unique
        childDiv.className = 'sortedTreeCell';
        parentContainer.appendChild(childDiv);
        childDiv.innerHTML = JSON.stringify(children[i]);
    }
}
