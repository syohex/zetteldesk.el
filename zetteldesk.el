;; -- DEPENDENCIES --
;; These are some functions that are needed for the package to work as
;; it should, but that are not specific to the package

(cl-defmethod org-roam-node-buffer ((node org-roam-node))
  "Access slot \"buffer\" of org-roam-node struct CL-X"
  (let ((buffer (get-file-buffer (org-roam-node-file node))))
    buffer))

(defun org-roam-node-poi-or-moc-p (NODE)
  "Check if NODE has the tag POI or the tag MOC. Return t if it does"
  (or (string-equal (car (org-roam-node-tags NODE)) "POI")
      (string-equal (car (org-roam-node-tags NODE)) "MOC")))

(defun org-roam-backlink-query ()
  "Simple org-roam query function that stores the IDs of all the files that link
  to the node at point. This is a modified part of the
  `org-roam-backlinks-get' function keeping only the part necessary for
  `org-roam-backlink-files' to work as this is a complimentary function to
  that"
  (org-roam-db-query
   [:select [source dest]
	    :from links
	    :where (= dest $s1)
	    :and (= type "id")]
   (org-roam-node-id (org-roam-node-at-point))))

;; -- PREDICATE FUNCTIONS --
;; This section contains the predicate functions the package uses. The
;; core of the package is that it provides well filtered completion
;; menus as chosen by the user, so obviously predicate functions are
;; core to the package

(defvar-local zetteldesk "default"
  "Buffer local variable that determines whether a buffer is part
  of the current zetteldesk. A buffer is part of the zetteldesk
  only if the value of this variable is not its default value in
  that buffer. Its default value is default because I am not
  creative.")

(defun zetteldesk-p (BUFFER)
  "Check if BUFFER is part of the current `zetteldesk'"
  (not (eq (default-value 'zetteldesk) (buffer-local-value 'zetteldesk (cdr BUFFER)))))

(defun zetteldesk-buffer-p (BUFFER)
  "Check if BUFFER is similtaneously part of the current
  `zetteldesk' and not a buffer for an org-roam file.

Org-roam file buffers are better viewed with `org-roam-node-file'
so this function filters down the database to non org-roam
zetteldesk buffers. This is what is used to create the filter
function `zetteldesk-switch-to-buffer'"
  (and (zetteldesk-p BUFFER) (not (org-roam-buffer-p (cdr BUFFER)))))

(defun zetteldesk-node-p (NODE)
  "Check if NODE is associated with an open buffer. If it is,
  check if that buffer is part of the current `zetteldesk'. If it
  isn't, return nil.

This function is used as a filter function to create
`zetteldesk-node-find' which is a filtered view of
`org-roam-node-find'"
  (if (org-roam-node-buffer NODE)
      (not (eq (default-value 'zetteldesk) (buffer-local-value 'zetteldesk (org-roam-node-buffer NODE))))
    nil))

(defun zetteldesk-org-buffer-p (BUFFER)
  "Check if BUFFER is part of the current `zetteldesk' an org
  file but not one that belongs to org-roam.

This is used as the filter function for
`zetteldesk-insert-org-file-contents' which prompts for an org
file, but as `zetteldesk-insert-node-contents' is a superior
version for org-roam nodes, that function should not prompts for
those files"
  (and (zetteldesk-buffer-p BUFFER) (eq (buffer-local-value 'major-mode (cdr BUFFER)) 'org-mode)))

(defun zetteldesk-pdf-p (BUFFER)
  "Check if BUFFER is part of the current `zetteldesk' and also a pdf file."
  (and (zetteldesk-p BUFFER) (eq (buffer-local-value 'major-mode (cdr BUFFER)) 'pdf-view-mode)))

;; -- ADD/REMOVE THINGS IN THE ZETTELDESK --
;; To get a system where the user can get multiple filtered views of
;; the nodes/buffers of their choice, obviously you need functions
;; that allow the user to add them to something. And then, you also
;; need ways to remove things, because people make mistakes.

(defvar zetteldesk-info-nodes '()
  "List of info nodes that are part of the
  zetteldesk. Initialised as an empty list")

(defun zetteldesk-add-to-desktop (BUFFER)
  "Add BUFFER to the current `zetteldesk'"
  (interactive "b")
  (with-current-buffer BUFFER
    (setq-local zetteldesk "foo")))

(defun zetteldesk-add-node-to-desktop ()
  "Add an org-roam-node to the `zetteldesk' and if there isn't a
  buffer associated to it, create it.

The node is read through `org-roam-node-read'"
  (interactive)
  (let* ((node (org-roam-node-read))
	 (buffer (org-roam-node-buffer node))
	 (file (org-roam-node-file node))
	 (org-startup-with-latex-preview nil))
    (if (not (eq buffer nil))
	(with-current-buffer buffer
	  (setq-local zetteldesk "foo"))
      (with-current-buffer (find-file-noselect file)
	(setq-local zetteldesk "foo")))))

(defun zetteldesk-add-backlinks-to-desktop ()
  "Add the current buffer and all its backlinks to the `zetteldesk'. 

This function queries the database for all the nodes that link to
the current node with the `org-roam-backlink-query' function and
then recursively checks if there is an open buffer associated
with them, and if so adds it to the `zetteldesk'"
  (interactive)
  (setq-local zetteldesk "foo")
  (let ((backlinks (length (org-roam-backlink-query)))
	(org-startup-with-latex-preview nil))
    (dotimes (number backlinks)
      (let* ((id (car (nth number (org-roam-backlink-query))))
	      (node (org-roam-node-from-id id))
	      (buffer (org-roam-node-buffer node))
	      (file (org-roam-node-file node)))
	(if (not (eq buffer nil))
	    (with-current-buffer buffer
	      (setq-local zetteldesk "foo"))
	  (with-current-buffer (find-file-noselect file)
	    (setq-local zetteldesk "foo")))))))

(defun zetteldesk-add-info-node-to-desktop ()
  "If the current buffer is an info node, add its name to the
list of the variable `zetteldesk-info-nodes'"
  (interactive)
  (add-to-list 'zetteldesk-info-nodes (Info-copy-current-node-name)))

(defun zetteldesk-remove-from-desktop (BUFFER)
  "Remove BUFFER from the current `zetteldesk'"
  (interactive "b")
  (with-current-buffer BUFFER
    (kill-local-variable 'zetteldesk)))

(defun zetteldesk-remove-node-from-desktop ()
  "Remove an org-roam-node from the `zetteldesk'. The node is
read through `org-roam-node-read'"
  (interactive)
  (let* ((node (org-roam-node-read nil #'zetteldesk-node-p))
	 (buffer (org-roam-node-buffer node)))
    (with-current-buffer buffer
      (kill-local-variable 'zetteldesk))))

(defun zetteldesk-remove-backlinks-from-desktop ()
  "Remove the current buffer and all its currently open backlinks
  from the `zetteldesk'.

This function is essentially a carbon copy of
`zetteldesk-add-backlinks-to-desktop' but instead of adding the
buffer to the desktop it removes it."
  (interactive)
  (kill-local-variable 'zetteldesk)
  (let ((backlinks (length (org-roam-backlink-query))))
    (dotimes (number backlinks)
      (let* ((id (car (nth number (org-roam-backlink-query))))
	      (node (org-roam-node-from-id id))
	      (buffer (org-roam-node-buffer node)))
	(unless (eq buffer nil)
	  (with-current-buffer buffer
	    (kill-local-variable 'zetteldesk)))))))

(defun zetteldesk-remove-info-node-from-desktop ()
  "Remove an info-node from the `zetteldesk'. The node is
selected through a `completing-read' menu of
`zetteldesk-info-nodes'"
  (interactive)
  (setq zetteldesk-info-nodes (remove
			       (completing-read "KEKW: " zetteldesk-info-nodes)
			       zetteldesk-info-nodes)))

;; -- FILTER FUNCTIONS --
;; This section is about defining all the functions that show you the
;; filtered results of all your nodes/buffers

(defun zetteldesk-switch-to-buffer ()
  "Execute `switch-to-buffer' with the buffer list being
filtered (using `zetteldesk-buffer-p') to show only buffers that are
part of the current `zetteldesk' and not `org-roam-node's."
  (interactive)
  (switch-to-buffer (read-buffer "Zetteldesk Buffers: " nil nil #'zetteldesk-buffer-p)))

(defun zetteldesk-node-find ()
  "Execute `org-roam-node-find' with the list being
filtered (using `zetteldesk-node-p') to show only nodes that are
part of the current `zetteldesk'"
  (interactive)
  (org-roam-node-find nil nil #'zetteldesk-node-p))

(defun zetteldesk-node-insert ()
  "Execute `org-roam-node-insert' with the list being
filtered (using `zetteldesk-node-p') to show only nodes that are
part of the current `zetteldesk'"
  (interactive)
  (org-roam-node-insert #'zetteldesk-node-p))

(defun zetteldesk-info-goto-node ()
  "Zetteldesk filter function for `Info-goto-node'.

Prompts the user to select a node from the list
`zetteldesk-info-nodes' and jumps to that node"
  (interactive)
  (Info-goto-node (completing-read "Nodes: " zetteldesk-info-nodes)))

;; -- *ZETTELDESK-SCRATCH* --
;; This is the section where it all comes together. The
;; zetteldesk-scratch buffer is a special buffer defined here on which
;; you drop all your stuff. Its what molds the whole workflow together

(define-minor-mode zetteldesk-mode
  "Toggles the global zetteldesk-mode.

When turned on, this mode initialises the *zetteldesk-scratch*
buffer, a useful part of the whole zetteldesk workflow."
  nil
  :global t
  :group 'zetteldesk
  :lighter " zetteldesk")

(defun zetteldesk--create-scratch-buffer ()
  "Create the zetteldesk-scratch buffer and put it in `org-mode'"
  (let ((buffer (generate-new-buffer "*zetteldesk-scratch*"))
	(org-startup-with-latex-preview nil))
    (with-current-buffer buffer
      (org-mode))))

(add-hook 'zetteldesk-mode-on-hook 'zetteldesk--create-scratch-buffer)

(defun zetteldesk-switch-to-scratch-buffer (&optional arg)
  "Open the zetteldesk-scratch buffer in a split with the current buffer.

Optionally, with a `\\[universal-argument]' switch to the
*zetteldesk-scratch* buffer without issuing a split."
  (interactive "P")
  (if (equal arg '(4))
      (switch-to-buffer "*zetteldesk-scratch*")
    (switch-to-buffer-other-window "*zetteldesk-scratch*")))

(defun zetteldesk-node-insert-if-poi-or-moc ()
  "Filter `org-roam-node-list' to only include files in the current
`zetteldesk' that have the POI or MOC tag with `zetteldesk-node-p' and
`org-roam-node-poi-or-moc-p'. Then insert a link to every one of those nodes
and seperate them with commas"
  (interactive)
  (let* ((init_list (org-roam-node-list))
	 (zetteldesk_nodes (cl-remove-if-not #'zetteldesk-node-p init_list))
	 (nodes_poi (cl-remove-if-not #'org-roam-node-poi-or-moc-p zetteldesk_nodes)))
    (while nodes_poi
      (let* ((node (car nodes_poi))
	     (description (org-roam-node-formatted (car nodes_poi))))
	(insert (org-link-make-string
		 (concat "id:" (org-roam-node-id (car nodes_poi)))
		 description))
	(insert ", "))
      (setq nodes_poi (cdr nodes_poi)))))

(defun zetteldesk-insert-node-contents (&optional arg)
  "Select a node that is part of the current `zetteldesk', add a link
  to it at point and then insert its contents to the bottom of the 
  *zetteldesk-scratch* buffer after inserting a newline there. Remove
  the first 67 characters which is the properties section if it only
  contains the ID of the node as its unneeded and change the string
  #+title to a top level heading as its more practical when inserting
  the contents of multiple files.

If given a `\\[universal-argument]' also switch to the *zetteldesk-scratch* buffer
in a split."
  (interactive "P")
  (let* ((node (org-roam-node-read nil #'zetteldesk-node-p))
	 (file (org-roam-node-file node))
	 (description (org-roam-node-formatted node)))
    (insert (org-link-make-string
	     (concat "id:" (org-roam-node-id node))
	     description))
    (with-current-buffer "*zetteldesk-scratch*"
      (goto-char (point-max))
      (newline)
      (insert-file-contents file nil 67)
      (replace-string "#+title: " "* ")))
  (when (equal arg '(4))
    (save-current-buffer
      (switch-to-buffer-other-window "*zetteldesk-scratch*"))))

(defun zetteldesk-insert-node-contents-without-link ()
  "\"Sister function\" of
  `zetteldesk-insert-node-contents'. Finds a node that is part of
  the `zetteldesk' and inserts its contents to the bottom of the
  zetteldesk-scratch buffer. This function differentiates itself,
  by the fact that it doesn't insert an ID link to the node in
  the current buffer and by the fact that it switches to the
  scratch buffer in a split without needing a
  `\\[universal-argument]'.

For me, it makes sense a lot of the time to insert a link to the
node inthe current buffer, especially if its an outlining
buffer. But sometimes its not handy, and so, I just made this
second iteration to fix that issue."
  (interactive)
  (let* ((node (org-roam-node-read nil #'zetteldesk-node-p))
	 (file (org-roam-node-file node)))
    (with-current-buffer "*zetteldesk-scratch*"
      (goto-char (point-max))
      (newline)
      (insert-file-contents file nil 67)
      (replace-string "#+title: " "* ")))
  (switch-to-buffer-other-window "*zetteldesk-scratch*"))

(defun zetteldesk-insert-org-file-contents (&optional arg)
  "Select an org buffer (excluding org-roam files) that is part of the
  current `zetteldesk', insert its contents to the
  *zetteldesk-scratch* buffer, make its title a top level heading and
  demote all of its headings by one level (since the title now acts as
  a top level heading).

If given a `\\[universal-argument]' also switch to the
*zetteldesk-scratch* buffer in a split"
  (interactive "P")
  (let* ((buffer (set-buffer (read-buffer "Zetteldesk Buffers: " nil nil #'zetteldesk-org-buffer-p)))
	 (file (buffer-file-name buffer)))
    (set-buffer "*zetteldesk-scratch*")
    (goto-char (point-max))
    (save-excursion
      (newline)
      (insert-file-contents file))
    (save-excursion
      (while (not (org-next-visible-heading 1))
	(org-metaright)))
    (replace-string "#+title: " "* "))
  (when (equal arg '(4))
    (switch-to-buffer-other-window "*zetteldesk-scratch*")))

(defun zetteldesk-insert-link-to-pdf (&optional arg)
  "Select a pdf file that is part of the `zetteldesk' and prompt for a
  page in that pdf (defaults to page 1 if you don't care about the
  page).

Then, in the zetteldesk-scratch buffer, insert at `point-max' a
newline and then a new heading with its name consisting of the
string \"Supportive Material - \" then the pdfs name, without the
file structure or the extension and then the string
\"(PDF)\". Then, insert a newline, the string \"Link to PDF: \"
and then a link to the chosen pdf, in the correct page, with the
description being the pdfs name without the file structure or the
extension.

Optionally, if given a `\\[universal-argument]' save the
highlighted region in a variable and insert it after the heading
but before the pdf link. This functionality serves the purpose of
adding a \"description\" sort of thing to the pdf. Typically,
when citing a pdf as supplementary info to an argument, there is
something specific you want to take from the pdf. Therefore, this
optional addition, adds that to the scratch buffer so you
remember why it was useful."
  (interactive "P")
  (let* ((contents (buffer-substring (mark) (point)))
	 (pdf-buffer (set-buffer (read-buffer "Zetteldesk Pdfs: " nil nil #'zetteldesk-pdf-p)))
	 (file (buffer-file-name pdf-buffer))
	 (page (read-from-minibuffer "Page: " "1"))
	 (description (file-name-nondirectory (file-name-sans-extension file))))
    (with-current-buffer "*zetteldesk-scratch*"
      (goto-char (point-max))
      (newline)
      (org-insert-heading)
      (insert "Supportive Material - " description " (PDF)")
      (newline)
      (when (equal arg '(4))
	(insert contents)
	(newline))
      (insert "Link to PDF: "
	      (org-link-make-string
	       (concat "pdf:" file "::" page)
	       description)))))

(defun zetteldesk-insert-info-contents (&optional arg)
  "Select an info node that is part of the current `zetteldesk'
  using a `completing-read' prompt for the selection.

Then, in the *zetteldesk-scratch* buffer, go to the end of the
buffer, insert a newline and a heading of the form \"Supportive
Material - \" the node's name \"(Info)\" akin to what is done in
`zetteldesk-insert-link-to-pdf'. Then, insert the contents of the
chosen info node, removing the first 2 lines which have the
contextual links of the buffer, as they are not functional
outside of the info buffer. Also insert a link with the title
\"See this node in its context\" which opens the node inside the
info program. Finally, restore the buffer from which this
function was called. Ideally, this wouldn't require a
switch-to-buffer statement, but the function `Info-goto-node'
used for this function switches the visible buffer to the info
node and I couldn't find an alternative that only makes it
current for editing operations, but doesn't change the visible
buffer to it.

I find the link to the actual info buffer is useful as a lot of
the time, you might want to insert the buffer so you can store it
with other useful information inside the zetteldesk-scratch
buffer, but then, you are interested in looking into the other
nodes of the manual you were reading.

Optionally, with a `\\[universal-argument]' switch to the
zetteldesk-scratch buffer in a split."
  (interactive "P")
  (let ((info_node (completing-read "Nodes: " zetteldesk-info-nodes))
	(buffer (current-buffer)))
    (Info-goto-node info_node)
    (with-current-buffer "*zetteldesk-scratch*"
      (goto-char (point-max))
      (newline)
      (org-insert-heading)
      (insert "Supportive Material - " info_node " (Info)")
      (newline)
      (save-excursion (insert-buffer-substring "*info*")
		      (insert
		       (org-link-make-string
			(concat "elisp:(Info-goto-node \"" info_node "\")")
			"See this node in its context")))
      (kill-whole-line 2))
    (switch-to-buffer buffer)
    (when (equal arg '(4))
      (switch-to-buffer-other-window "*zetteldesk-scratch*"))))

(provide 'zetteldesk)
