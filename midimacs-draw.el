(eval-when-compile
  (require 'cl))
(require 'midimacs-globals)

(defun midimacs-draw (&optional contents)
  (with-current-buffer (midimacs-buffer-seq)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (midimacs-draw-top-bar)
      (when contents
        (insert contents))
      (goto-char (point-min)))))

(defun midimacs-draw-top-bar ()
  (with-current-buffer (midimacs-buffer-seq)
    (let ((inhibit-read-only t))
      (goto-char (point-min))
      (midimacs-draw-top-bar-numbers)
      (midimacs-draw-top-bar-background-overlay)
      (midimacs-make-top-bar-read-only)
      (midimacs-redraw-repeat-start)
      (midimacs-redraw-repeat-end)
      (midimacs-redraw-play)
      (end-of-line)
      (insert "\n"))))

(defun midimacs-redraw-repeat-start ()
  (unless (and midimacs-repeat-start-overlay (overlay-buffer midimacs-repeat-start-overlay))
    (setq midimacs-repeat-start-overlay (make-overlay 0 1))
    (overlay-put midimacs-repeat-start-overlay 'display "[")
    (overlay-put midimacs-repeat-start-overlay 'face 'midimacs-repeat-face))
  (let ((pos (+ (midimacs-time-beat midimacs-repeat-start) midimacs-left-bar-length)))
    (move-overlay midimacs-repeat-start-overlay pos (1+ pos))))

(defun midimacs-redraw-repeat-end ()
  (unless (and midimacs-repeat-end-overlay (overlay-buffer midimacs-repeat-end-overlay))
    (setq midimacs-repeat-end-overlay (make-overlay 0 1))
    (overlay-put midimacs-repeat-end-overlay 'display "]")
    (overlay-put midimacs-repeat-end-overlay 'face 'midimacs-repeat-face))
  (let ((pos (+ 1 (midimacs-time-beat midimacs-repeat-end) midimacs-left-bar-length)))
    (move-overlay midimacs-repeat-end-overlay pos (1+ pos))))

(defun midimacs-redraw-play ()
  (unless (and midimacs-play-overlay (overlay-buffer midimacs-play-overlay))
    (setq midimacs-play-overlay (make-overlay 0 1))
    (overlay-put midimacs-play-overlay 'face 'midimacs-play-face))
  (overlay-put midimacs-play-overlay 'display (midimacs-play-symbol))
  (let ((pos (+ 1 (midimacs-time-beat midimacs-song-time) midimacs-left-bar-length)))
    (move-overlay midimacs-play-overlay pos (1+ pos))))

(defun midimacs-draw-top-bar-numbers ()
  (goto-char (point-min))
  (delete-region (point) (line-end-position))
  (insert (make-string midimacs-left-bar-length ? ))
  (loop for i from 0 below midimacs-length by 4
        do (insert (format "%-4d" i))))

(defun midimacs-draw-top-bar-background-overlay ()
  (goto-char (point-min))
  (let ((overlay (make-overlay (point) (line-end-position))))
    (overlay-put overlay 'face 'midimacs-top-bar-background-face)))

(defun midimacs-make-top-bar-read-only ()
  (goto-char (point-min))
  (put-text-property (point) (line-end-position) 'read-only t))

(defun midimacs-play-symbol ()
  (cond ((eq midimacs-state 'playing)   "▶")
        ((eq midimacs-state 'recording) "●")
        ((eq midimacs-state 'stopped)   "◾")))

(provide 'midimacs-draw)
