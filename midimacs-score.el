(eval-when-compile
  (require 'cl))
(require 'midimacs-globals)
(require 'midimacs-time)
(require 'midimacs-util)

(defun midimacs-quantized-song-time ()
  (let ((seconds-per-tick (/ 60 (* midimacs-ticks-per-beat midimacs-bpm)))
        (seconds-since-tick (- (float-time) midimacs-last-tick-seconds)))
    (if (> seconds-since-tick (/ seconds-per-tick 2))
        (midimacs-time+ midimacs-song-time (make-midimacs-time :tick 1))
      midimacs-song-time)))

(defun midimacs-add-note-to-score (score time pitch duration)
  (midimacs-score-add-note score time pitch duration)
  (midimacs-score-update-buffer score))

(defun midimacs-remove-note-from-score (score time)
  (midimacs-score-remove-note score time)
  (midimacs-score-update-buffer score))

(defun midimacs-score-update-buffer (score)
  (with-current-buffer (midimacs-score-buffer score)
    (midimacs-edit-score
     old-score
     score)))

(defun midimacs-score-add-note (score time pitch duration)
  (let ((notes (midimacs-score-notes score)))
    (setf (midimacs-score-notes score)
          (loop for (tm p d) being the elements of notes using (index i) 
                while (midimacs-time>= time tm)
                finally (return (nconc (subseq notes 0 i)
                                       (list (list time pitch duration))
                                       (subseq notes i)))))))

(defun midimacs-score-remove-note (score time)
  (let ((notes (midimacs-score-notes score)))
    (setf (midimacs-score-notes score)
          (loop for (tm p d) being the elements of notes using (index i) 
                while (not (midimacs-time= time tm))
                finally (return (nconc (subseq notes 0 i)
                                       (subseq notes (1+ i))))))))

(defun* midimacs-score-text (score &key (hide-times nil))
  (let ((notes (if hide-times
                   (midimacs-score-notes-with-pauses score)
                 (midimacs-score-notes-without-pauses score))))
    (concat
     "(midimacs-score"
     (loop for (tm p d) being the elements of notes using (index i)
           for time-string = (intern (midimacs-time-to-string tm))
           for duration-string = (intern (midimacs-time-to-string d))
           concat "\n"
           if hide-times
             concat (format "(%-5s %s)" (or p "-") duration-string)
           else
             concat (format "(%-9s %-5s %s)" time-string (or p "-") duration-string))
     ")\n")))

(defun midimacs-score-indent ()
  (save-excursion
    (let ((pos))
      (search-backward "(midimacs-score")
      (setq pos (point))
      (forward-char 1)
      (up-list)
      (indent-region pos (point)))))

(defun midimacs-score-notes-without-pauses (score)
  (loop for (time pitch duration) in (midimacs-score-notes score)
        if pitch
        collect (list time pitch duration)))

(defun midimacs-score-notes-with-pauses (score)
  (let* ((notes (midimacs-score-sorted-notes score)))
    (loop for (time pitch duration) in notes
          with cum-time = (make-midimacs-time)
          append (let ((notes (midimacs-note-with-pause time pitch duration cum-time)))
                   (setq cum-time (midimacs-time+ time duration))
                   notes))))

(defun midimacs-note-with-pause (time pitch duration cum-time)
  (cond ((midimacs-time< time cum-time) (user-error "Score is polyphonic"))
        ((midimacs-time= time cum-time) (list (list time pitch duration)))
        ((midimacs-time> time cum-time) (list (list cum-time nil (midimacs-time- time cum-time))
                                              (list time pitch duration)))))

(defun midimacs-score-sorted-notes (score)
  (let ((notes (midimacs-score-notes score)))
    (cl-sort notes 'midimacs-time< :key (lambda (x) (elt x 0)))))

(defun midimacs-get-recording-score ()
  (let* ((code (midimacs-code-at-point))
         (event (midimacs-event-at-point))
         (track (midimacs-track-at-point))
         (score)
         (start-time (midimacs-event-start-time event)))

    (unless code
      (user-error "No code here"))

    (midimacs-code-open-window code)
    (setq score (make-midimacs-score :buffer (current-buffer)
                                     :channel (midimacs-track-channel track)
                                     :start-time start-time))

    (midimacs-code-insert-score code score)

    (other-window 1) ;; switch back to seq
    score))

(defun midimacs-code-insert-score (code score)
  (goto-char (point-min))
  (unless (search-forward "(midimacs-run" nil t)
    (error "No midimacs-run in this buffer"))

  (forward-line)

  (if (search-forward "(midimacs-score" nil t)
      (progn
        (midimacs-score-update-buffer score))
    (insert "\n")
    (insert (midimacs-score-text score))
    (midimacs-score-indent)))

(defun midimacs-parse-score (score-text)
  (let* ((form (read score-text))
         (raw-notes (subseq form 1))
         (cum-time (make-midimacs-time))
         (notes (loop for note in raw-notes
                      collect (destructuring-bind (time pitch duration)
                                  (midimacs-score-parse-note note)
                                (unless time
                                  (setq time cum-time))
                                (setq cum-time (midimacs-time+ cum-time duration))
                                (list time pitch duration)))))
    (make-midimacs-score :notes notes)))

(defun midimacs-score-parse-note (note)
  (let ((time-s) (pitch-s) (duration-s))
    (destructuring-bind (m1 m2 &optional m3) note
      (if m3
          (setq time-s m1
                pitch-s m2
                duration-s m3)
        (setq time-s nil
              pitch-s m1
              duration-s m2))
      (list (when time-s (midimacs-parse-time time-s))
            (if (eq pitch-s '-) nil pitch-s)
            (midimacs-parse-time duration-s)))))

(defun midimacs-score-split-text (text)
  (save-excursion
    (let ((start-pos (midimacs-first-score-pos text))
          (end-pos))
      (goto-char start-pos)
      (forward-char 2)
      (up-list)
      (setq end-pos (point))
      (list
       (substring text (1- (point-min)) start-pos)
       (substring text start-pos end-pos)
       (substring text end-pos (1- (point-max)))))))

(defun midimacs-first-score-pos (text)
  (string-match "(midimacs-score" text))

(defmacro midimacs-edit-score-text (arg &rest body)
  `(let ((text (buffer-substring-no-properties (point-min) (point-max)))
         (p (point)))
     (destructuring-bind (before ,arg after)
         (midimacs-score-split-text text)
       (let ((new-score-text (progn ,@body)))
         (erase-buffer)
         (insert before)
         (insert new-score-text)
         (midimacs-score-indent)
         (insert after)
         (goto-char p)))))

(defmacro midimacs-edit-score (arg &rest body)
  `(midimacs-edit-score-text
    score-text
    (let ((,arg (midimacs-parse-score score-text)))
      (midimacs-score-text (progn ,@body) :hide-times nil))))

(defmacro midimacs-edit-notes (arg &rest body)
  `(midimacs-edit-score
    score
    (let ((,arg (midimacs-score-notes score)))
      (setf (midimacs-score-notes score) (progn ,@body))
      score)))

(defun midimacs-code-score-hide-times ()
  (interactive)
  (midimacs-edit-score-text
   score-text
   (midimacs-score-text (midimacs-parse-score score-text) :hide-times t)))

(defun midimacs-code-score-show-times ()
  (interactive)
  (midimacs-edit-score-text
   score-text
   (midimacs-score-text (midimacs-parse-score score-text))))

(defun midimacs-score-quantize-times (subdiv-s)
  (interactive "sQuantize to: ")
  (midimacs-edit-notes
   notes
   (let ((subdiv (midimacs-parse-time subdiv-s)))
     (midimacs-quantize-note-times notes subdiv))))

(defun midimacs-quantize-note-times (notes subdiv)
  (loop for (time pitch duration) in notes
        collect (list (midimacs-time-quantize time subdiv) pitch duration)))

(defun midimacs-score-quantize-durations (subdiv-s)
  (interactive "sQuantize to: ")
  (midimacs-edit-notes
   notes
   (let ((subdiv (midimacs-parse-time subdiv-s)))
     (midimacs-quantize-note-durations notes subdiv))))

(defun midimacs-quantize-note-durations (notes subdiv)
  (loop for (time pitch duration) in notes
        collect (list time pitch (midimacs-time-quantize duration subdiv))))

(defun midimacs-score-move (delta-s)
  (interactive "sMove by: ")
  (let ((negative (string-prefix-p "-" delta-s))
        (delta))
    (when (or negative (string-prefix-p "+" delta-s))
      (setq delta-s (substring delta-s 1)))
    (setq delta (midimacs-parse-time delta-s))
    (when negative
      (setq delta (midimacs-time- delta)))
    (midimacs-edit-notes
     notes
     (midimacs-score-move-notes notes delta))))

(defun midimacs-score-move-notes (notes delta)
  (loop for (time pitch duration) in notes
        collect (list (midimacs-time+ time delta) pitch duration)))

(defun midimacs-recording-score-clear-ahead ()
  (midimacs-remove-note-from-score
   midimacs-recording-score
   (midimacs-time- midimacs-song-time
                   (midimacs-score-start-time midimacs-recording-score)
                   (make-midimacs-time :tick -1)))) ;; one ahead

(provide 'midimacs-score)

;; Local variables:
;; byte-compile-warnings: (not cl-functions)
;; End:
