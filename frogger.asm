#####################################################################
#
#
# Student: Chloe Huang
#
#
#
#
 # CSC258H5S Fall 2021 Assembly Final Project
 # University of Toronto, St. George
 # Bitmap Display Configuration:
 # - Unit width in pixels: 8
 # - Unit height in pixels: 8
 # - Display width in pixels: 256
 # - Display height in pixels: 256
 # - Base Address for Display: 0x10008000 ($gp)

 # Which approved additional features have been implemented?
 # 1. (easy) Display the number of lives remaining (onto the message box)
 # 2. (easy) Dynamic increase in difficulty (speed, obstacles, etc.) as game progresses: 
 # 	obstacles move in a much faster speed  after each time the frog fills an empty hole in the goal region
 # 3. (easy) Display a death/respawn animation each time the player loses a frog:  
 #	if a frog collides with vehicle/water, it falls apart, i.e. only four corners left, and then reappear at the start region.
 # 4. (hard) Display the player’s score at the top of the screen.
 # 5. (hard) Make a second level that starts after the player completes the first level
 #	after the user fills all 3 empty holes in the first level, the user goes to the second level;
 #	the second level has longer vehicle, shorter log and faster speed.
.data 
	# data for drawing background
	displayAddress: .word 0x10008000
	rowColPixelSize: .word 32	# 32 pixel in height and width
	
	startGoalRegionColor: .word 0xb09cff
	emptyGoalHoleColor: .word 0xfa9d00
	waterColor: .word 0x3498db
	safeColor: .word 0xff99bb
	roadColor: .word 0x515c5d
	scoreColor: .word 0xffffff
	drawBgCount: .word 127	# Every time, we paint a region of size 128 (4 x 32 pixel), so count 128 times (127 - 0)
	
	goalRowSpace2: .word 0xb09cff:512	# the array for 2nd row of goal region
	
	# data for drawing objects
	frogColor: .word 0xa9ff17
	frogX: .word 12	# the x-coordinate of top left frog (first row: x: 0 -> 31 pixel)
	frogY: .word 28 # the y-coordinate of top left frog (first col: y: 0 -> 31 pixel)
	
	vehicleColor: .word 0xed3624
	vehicleRowSpaceTemplate: .word 0x515c5d:512
	vehicleRowSpace1: .word 0x515c5d:512	# 1st row of vehicle + road needs 512 pixels, colors all initialized to roadColor
	vehicleRowSpace2: .word 0x515c5d:512	# 2nd row of vehicle + road needs 512 pixels, colors all initialized to roadColor
	vehicleFirstRow: .word 2560	# the address between display address & the top left corner of first row the vehicle is in
	vehicleSecondRow: .word 3072	# the address between display address & the top left corner of second row the vehicle is in
	vehicleLength: .word 28		# # expand in 8 pixels (0-7 pixel, 28 bytes)
	
	logColor: .word 0x946635
	logRowSpaceTemplate: .word 0x3498db: 512
	logRowSpace1: .word 0x3498db: 512	# 1st row of log + water needs 512 pixels, colors all initialized to waterColor
	logRowSpace2: .word 0x3498db: 512
	logFirstRow: .word 1024
	logSecondRow: .word 1536
	logLength: .word 28 	# expand in 8 pixels (0-7 pixel, 28 bytes)
	
	# Things for displaying on screen
	startText: .asciiz "Game starts now! You have 3 lives."
	livesText: .asciiz "Your remaining lives: "
	lives: .word 3	# if lives = 0, no live
	deadText: .asciiz "Ah oh... No live is left. Game ends."
	newline: .asciiz "\n"
	endText: .asciiz "Game Ends."
	
	GoalHoleFilled: .word 0	# the number of empty hole that the frog fills
	score: .word 0 # the score of the frog
	winText: .asciiz "Congratulation! You win!"
	levelCompleted: .word 0	# total 2 levels; each level, frog needs to fill in 3 empty holes
	
	# initially, log/vehicle sleep time = 0.5s
	sleepTime: .word 700	# every time user fills a hole, sleep time decreases
	
.text
main:
	jal PrintGameStartMsg
	jal AllocateGoalInitial
	jal AllocateVehicleLog	# Allocate vehicles/logs
	jal DrawBackground	# draw the background (all objects + score, except frog)
	jal DrawFrog
mainLoop:
	jal CheckKeyboardPress	# check if there is some input, and draw the new frog
	jal CheckCollision	# collision with vehicle/water/empty goal hole; renew frog if collides
	jal UpdateVehicleLogLocation	# update locations of vehicles/logs, no drawing involved
	jal UpdateOnLogFrogPos	# if frog is on log, update its position to move with frog
	jal DrawBackground	# draw the updated background (except frog)
	jal DrawFrog		# draw the frog
	
	lw $a0, sleepTime	# sleep time: 0.5s
	addi $sp, $sp, -4
	sw $a0, 0($sp)		# store the sleep time into stack as a parameter
	jal Sleep	# sleep for some time
	j mainLoop

PrintGameStartMsg: # print start message
	# print start text
	li $v0, 4
	la $a0, startText
	syscall
	
	# print new line
	li $v0, 4
	la $a0, newline
	syscall
	
	jr $ra

UpdateOnLogFrogPos:
	addi $sp, $sp, -4
	sw $ra, 0($sp)	# store the returning address to main
	
	lw $t0, frogY	# load frog y-coordinate
	beq $t0, 8, MoveOnLogFrogLeft	# on first row of log, need move left
	beq $t0, 12, MoveOnLogFrogRight
	
	# else, frog is not on log, back to main
	lw $ra, ($sp)
	addi $sp, $sp, 4
	jr $ra	# updated the frog's position to right
	
MoveOnLogFrogLeft:
	lw $t1, frogX	# t1 stores frog x value
	la $t2, frogX	# t2 stores the address storing frog x value
	addi $t1, $t1, -1	# frog x - 4
	beq $t1, -1, WrapOnLogFrogToRight
	sw $t1, ($t2)
	
	lw $ra, ($sp)
	addi $sp, $sp, 4
	jr $ra	# updated the frog's position to right
WrapOnLogFrogToRight:	# if frog goes out of range on left
	addi $t1, $zero, 28
	
	lw $ra, ($sp)
	addi $sp, $sp, 4
	jr $ra	# updated the frog's position to right
	
MoveOnLogFrogRight:	# without drawing
	lw $t1, frogX	# t1 stores frog x value
	la $t2, frogX	# t2 stores the address storing frog x value
	addi $t1, $t1, 1
	beq $t1, 32, WrapOnLogFrogToLeft	# goes out of range
	sw $t1, ($t2)
	
	lw $ra, ($sp)
	addi $sp, $sp, 4
	jr $ra	# updated the frog's position to right
WrapOnLogFrogToLeft:
	addi $t1, $zero, 0
	sw $t1, ($t2)
	
	lw $ra, ($sp)
	addi $sp, $sp, 4
	jr $ra	# updated the frog's position to right
	
# Part1: Drawing screen
# Part1.1: Allocate goal region
AllocateGoalInitial:	# the initial call from main to allocate goal region with all holes empty (road color)
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address to main
	
	lw $a1, emptyGoalHoleColor	# $a1 = empty hole color
	
	# Allocate the first empty hole
	addi $a0, $zero, 16		# distance: top left corner of first empty hole  away from the array's start address
	jal AllocateOneGoalHole
	
	# Allocate the second empty hole
	addi $a0, $zero, 48		# store top left corner of second empty hole
	jal AllocateOneGoalHole
	
	# Allocate the third empty hole
	addi $a0, $zero, 80		# store top left corner of third empty hole
	jal AllocateOneGoalHole
	
	lw $ra, 0($sp)	# remove returning address to main
	addi $sp, $sp, 4
	jr $ra	# Go back to main

AllocateOneGoalHole:
	# parameters:
	# - a0 stores each allocating position's x-coordinate * 5
	# - a1 color for the hole
	la $t8, goalRowSpace2	# $t8 = start address of goalRowSpace2
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address to the most recent call
	addi $t7, $zero, 3	# draw four times (lines)
AllocateOneGoalHoleLoop:
	bltz $t7, BackToAllocateGoalInitial # if already draw four times (lines), exit
	jal AllocateGoalHoleOneLine	# draw first 4 pixels in a row
	
	addi $a0, $a0, 128	# j += 128, draw on the next line
	addi $t7, $t7, -1
	j AllocateOneGoalHoleLoop
	
BackToAllocateGoalInitial:
	lw $ra, 0($sp)	# remove returning address from stack
	addi $sp, $sp, 4
	jr $ra	# Go back to most recent call (AllocateGoalInitial)
	
AllocateGoalHoleOneLine:	# draw one line, 4 pixels of one hole
	# Every loop initializes j = 0.
	# while (i <= 12): vehicleRowSpace[j] = vehicleColor/roadColor; i += 4; j += 4   where A is the row of the vehicle
	# $t1 stores i;   $a1 stores j;   $t3 stores 12;   $t8 stores the address of goalRowSpace2
	addi $t3, $zero, 12
	add $t1, $zero, $zero	# initializes i = 0
	
AllocateGoalHoleOneLineLoop:	# allocate 4 pixels with specific color
	bgt $t1, $t3, AllocateGoalHoleOneLineLoopDone	# if i > 12, end allocation
	add $t4, $a0, $t1	# t4 = a0 (j) + i	
	add $t9, $t8, $t4	# t9 hold address of vehicleRowSpace[j]
	sw $a1, 0($t9)		# save the color at $a1 (Vehicle color) at the address stored in $t9
	addi $t1, $t1, 4	# update i: i += 4
	j AllocateGoalHoleOneLineLoop
	
AllocateGoalHoleOneLineLoopDone:
	jr $ra	# Back to AllocateVLOneObjectLoop
	

# Part1.2: ALlocate vehicle/log
AllocateVehicleLog:
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address to main into stack
	# Allocate road row 1 (2 vehicles in the first row)
	la $t8, vehicleRowSpace1	# store address of vehicleRowSpace1
	lw $a0, vehicleColor
	lw $t3, vehicleLength
	jal AllocateVLOneRow	# initially, car (8) - road (8) - car (8) - road (8)
	
	# Allocate road row 2 (2 vehicles in the first row)
	la $t8, vehicleRowSpace2	# store address of vehicleRowSpace1
	lw $a0, vehicleColor
	lw $t3, vehicleLength
	jal AllocateVLOneRow
	
	# Allocate water row 1 (2 logs in the first row)
	la $t8, logRowSpace1	# store address of vehicleRowSpace1
	lw $a0, logColor
	lw $t3, logLength
	jal AllocateVLOneRow
	
	# Allocate water row 2 (2 logs in the second row)
	la $t8, logRowSpace2	# store address of vehicleRowSpace1
	lw $a0, logColor
	lw $t3, logLength
	jal AllocateVLOneRow
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to main
	
AllocateVLOneRow:	# Allocate 2 vehicles/ logs in a row
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address to AllocateVehicleRow
	# Allocate the first vehicle/log in row 1
	addi $a1, $zero, 0		# store j
	jal AllocateVLOneObject
	
	# Allocate the second vehicle/log in row 1
	addi $a1, $zero, 64		# store j
	jal AllocateVLOneObject
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# Go back to AllocateVehicleLog
	
AllocateVLOneObject:	# draw one object in one row/4 lines (four lines = 1 row)
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address to AllocateOneRow
	addi $t7, $zero, 3	# draw four times (lines)
AllocateVLOneObjectLoop:
	bltz $t7, BackToAllocateVLOneRow # if already draw four times (lines), exit
	jal AllocateVLOneLine	# draw first 8 pixels in a row
	
	addi $a1, $a1, 128	# j += 128, draw on the next line
	addi $t7, $t7, -1
	j AllocateVLOneObjectLoop
BackToAllocateVLOneRow:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# Go back to AllocateVLOneRow
	
AllocateVLOneLine:	# draw one line, 8 pixels of vehicle/ log
	# Every loop initializes j = 0.
	# while (i <= 28): vehicleRowSpace[j] = vehicleColor/roadColor; i += 4; j += 4   where A is the row of the vehicle
	# $t1 stores i;   $a1 stores j;   $t3 stores objectLength (28 = 8 pixel, note (8-1)*4=28);   $t8 stores the address of vehicleRowSpace
	add $t1, $zero, $zero	# initializes i = 0
	
AllocateVLOneLineLoop:	# allocate 8 pixels with specific color
	bgt $t1, $t3, AllocateVLOneLineLoopDone	# if i > 28, end allocation
	add $t4, $a1, $t1	# t4 = a1 (j) + i	
	add $t9, $t8, $t4	# t9 hold address of vehicleRowSpace[j]
	sw $a0, 0($t9)		# save the color at $a0 (Vehicle color) at the address stored in $t9
	addi $t1, $t1, 4	# update i: i += 4
	j AllocateVLOneLineLoop
	
AllocateVLOneLineLoopDone:
	jr $ra	# Back to AllocateVLOneObjectLoop
	
# Part1.2: Draw background
DrawBackground:
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address to main into stack
	lw $t0, displayAddress		# $t0 stores the base address for display
	addi $t1, $zero, 0		# $t1 stores the value that should add to displayAddress (helper for drawing)
	j DrawGoalRegion
	
DrawGoalRegion:
	lw $a0, startGoalRegionColor 	# $a0 stores the safe region colour code
	jal DrawBackgroundTemplate	# Draw 1st part of Goal region  (4x32 pixel)
	jal DrawGoalRow2		# Draw 2nd part of Goal region (4x32 pixel)
	jal DrawScore

DrawSafeRegion:
	addi $t1, $zero, 2048
	lw $a0, safeColor		# $a0 stores the safe region colour code
	jal DrawBackgroundTemplate

DrawStartRegion:
	addi $t1, $zero, 3584
	lw $a0, startGoalRegionColor	# $a0 stores the start region colour code
	jal DrawBackgroundTemplate

DrawWaterRoadRegion:
	jal DrawVehicleLog
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to main

# Below are functions for drawing a typical background of size (4 x 32 pixel) using color of $a0
DrawBackgroundTemplate:
	# parameters:
	#	$t0 = start address
	#	$t1 = bytes away from start address
	#	$a0 = color
	
	# j = 127
	# while (j >= 0): paint at $t5 = ($t0 + i) and i = i + 4 and j -= 1, using colour in $a0
	# $t4 = j;   $t1 = i;   $t1 = 128;
	lw $t4 drawBgCount	# initialize $t4 to store 127.
DrawBgLoop:
	bltz $t4, DrawBgDone	# if j < 0, stop drawing pixels
	add $t5, $t0, $t1	# $t5 = $t0 + i, so we can paint with $t5 + 0
	sw $a0, 0($t5)		# paint the pixel at $t5 with color at $a0
	addi $t1, $t1, 4	# i = i + 4
	subi $t4, $t4, 1	# j -= 1
	J DrawBgLoop		# Jump back to paint again
DrawBgDone:
	jr $ra	# back to DrawBackground

# Part1.3: Draw Score
DrawScore:
	# $a0 = GoalHoleFilled/score;    $a1 = address of the last pixel in the first row;    $a2 = scoreColor
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address
	
	lw $a0, score		# $a0 = score
	
	lw $t0, displayAddress	# $t0 = address of the first pixel
	addi $a1, $t0, 124	# $a1 = address of the last pixel in the first row
	
	lw $a2, scoreColor
	
	beq $a0, 0, DrawScoreZero
	beq $a0, 1, DrawScoreOne
	beq $a0, 2, DrawScoreTwo
	beq $a0, 3, DrawScoreThree
	beq $a0, 4, DrawScoreFour
	beq $a0, 5, DrawScoreFive
	beq $a0, 6, DrawScoreSix

DrawScoreZero:
	# Know:  $a0 = score;    $a1 = address of the last pixel in the first row;    $a2 = scoreColor
	
	# draw zero
	# first col
	sw $a2, ($a1)
	sw $a2, 128($a1)
	sw $a2, 256($a1)
	sw $a2, 384($a1)
	sw $a2, 512($a1)
	
	# second col
	sw $a2, -4($a1)
	sw $a2, -8($a1)
	sw $a2, 120($a1)
	sw $a2, 248($a1)
	sw $a2, 376($a1)
	sw $a2, 504($a1)
	
	# third col
	sw $a2, 508($a1)
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to call for draw score

DrawScoreOne:
	# Know:  $a0 = GoalHoleFilled/score;    $a1 = address of the last pixel in the first row;    $a2 = scoreColor
	
	# draw
	sw $a2, 512($a1)
	
	sw $a2, -4($a1)
	sw $a2, 124($a1)
	sw $a2, 252($a1)
	sw $a2, 380($a1)
	sw $a2, 508($a1)
	
	sw $a2, 120($a1)
	sw $a2, 504($a1)
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to call for draw score

DrawScoreTwo:
	# Know:  $a0 = GoalHoleFilled/score;    $a1 = address of the last pixel in the first row;    $a2 = scoreColor
	
	# first col
	sw $a2, 0($a1)
	sw $a2, 128($a1)
	sw $a2, 256($a1)
	sw $a2, 512($a1)
	
	# second col
	sw $a2, -4($a1)
	sw $a2, 252($a1)
	sw $a2, 508($a1)
	
	# third col
	sw $a2, -8($a1)
	sw $a2, 248($a1)
	sw $a2, 376($a1)
	sw $a2, 504($a1)
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to call for draw score

DrawScoreThree:
	# Know:  $a0 = GoalHoleFilled/score;    $a1 = address of the last pixel in the first row;    $a2 = scoreColor
	
	# first col
	sw $a2, ($a1)
	sw $a2, 128($a1)
	sw $a2, 256($a1)
	sw $a2, 384($a1)
	sw $a2, 512($a1)
	
	# second col
	sw $a2, -4($a1)
	sw $a2, 252($a1)
	sw $a2, 508($a1)
	
	# third col
	sw $a2, -8($a1)
	sw $a2, 248($a1)
	sw $a2, 504($a1)
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to call for draw score

DrawScoreFour:
	# Know:  $a0 = GoalHoleFilled/score;    $a1 = address of the last pixel in the first row;    $a2 = scoreColor
	
	# first col
	sw $a2, ($a1)
	sw $a2, 128($a1)
	sw $a2, 256($a1)
	sw $a2, 384($a1)
	sw $a2, 512($a1)
	
	# second col
	sw $a2, 252($a1)

	# third col
	sw $a2, -8($a1)
	sw $a2, 120($a1)
	sw $a2, 248($a1)
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to call for draw score

DrawScoreFive:
	# Know:  $a0 = GoalHoleFilled/score;    $a1 = address of the last pixel in the first row;    $a2 = scoreColor
	
	# first col
	sw $a2, ($a1)
	sw $a2, 256($a1)
	sw $a2, 384($a1)
	sw $a2, 512($a1)
	
	# second col
	sw $a2, -4($a1)
	sw $a2, 252($a1)
	sw $a2, 508($a1)

	# third col
	sw $a2, -8($a1)
	sw $a2, 120($a1)
	sw $a2, 248($a1)
	sw $a2, 504($a1)
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to call for draw score

DrawScoreSix:
	# Know:  $a0 = GoalHoleFilled/score;    $a1 = address of the last pixel in the first row;    $a2 = scoreColor
	
	# first col
	sw $a2, ($a1)
	sw $a2, 256($a1)
	sw $a2, 384($a1)
	sw $a2, 512($a1)
	
	# second col
	sw $a2, -4($a1)
	sw $a2, 252($a1)
	sw $a2, 508($a1)

	# third col
	sw $a2, -8($a1)
	sw $a2, 120($a1)
	sw $a2, 248($a1)
	sw $a2, 376($a1)
	sw $a2, 504($a1)
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to call for draw score
	
# Part1.2: draw objects
# Part1.2.1: draw frog
DrawFrog:
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address to main into stack
	
	jal GetFrogLeftCornerAddress	# $t5 stores the frog's top left corner's address
	lw $t9 frogColor	# $t9 stores the colour of frog
	
	# Draw the frog from the top left corner pixel-by-pixel
	sw $t9, 0($t5)		# Draw the top left corner of the frog
	sw $t9, 12($t5)
	sw $t9, 128($t5)
	sw $t9, 132($t5)
	sw $t9, 136($t5)
	sw $t9, 140($t5)
	sw $t9, 260($t5)
	sw $t9, 264($t5)
	sw $t9, 384($t5)
	sw $t9, 396($t5)
	
	lw $ra, 0($sp)	# remove the final returning address from stack
	addi $sp, $sp, 4
	jr $ra	# Back to main

GetFrogLeftCornerAddress:
	lw $t0, displayAddress
	lw $t1, frogX	# $t1 stores x-coordinate of frog
	lw $t2, frogY
	lw $t3, rowColPixelSize	# $t3 stores the size of the row/col which is 32 pixel
	addi $t4, $zero, 4	# $t4 stores the bytes(4) we should move 
	
	# $t5 stores the address of the left top corner of the frog
	mul $t5, $t2, $t3	# The number of pixels in rows above y
	add $t5, $t5, $t1	# The number of pixels from (0,0) to (x,y)
	mul $t5, $t4, $t5	# The number of bytes away from (0,0)
	add $t5, $t5, $t0	# The address of the left top corner
	
	jr $ra

#Part1.2.2: draw allocated goal region (row2)
DrawGoalRow2:
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store returning address to DrawBackground into stack
	lw $t0, displayAddress	# t0: display address;
	
	la $t2, goalRowSpace2	# starting address of the row array
	li $t5, 512		# t5 represent the bytes between  the display address  and the top left corner of the vehicle in a row
	add $t5, $t5, $t0	# t5 = address of the top left corner in that row;
	jal DrawAllocateOneRow	# Draw first row of vehicle
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# Draw done; back to DrawBackground

DrawVehicleLog:	# Draw rows of vehicles/logs
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store returning address to DrawBackground into stack
	lw $t0, displayAddress	# t0: display address;
	
	# Draw first row of vehicle
	la $t2, vehicleRowSpace1	# address of the row array which stores the position of vehicles in the first row
	lw $t5, vehicleFirstRow	# t5 represent the bytes between  the display address  and the top left corner of the vehicle in a row
	add $t5, $t5, $t0	# t5 = address of the top left corner in that row;
	jal DrawAllocateOneRow	# Draw first row of vehicle
	
	# Draw second row of vehicle
	la $t2, vehicleRowSpace2	# address of the row array which stores the position of vehicles in the 2nd row
	lw $t5, vehicleSecondRow	# t5 represent the bytes between  the display address  and the top left corner of the vehicle in a row
	add $t5, $t5, $t0	# t5 = address of the top left corner of the vehicle in that row;
	jal DrawAllocateOneRow	# Draw second row

	# Draw first row of log:
	la $t2, logRowSpace1	# address of the row array which stores the position of logs in the 1st row
	lw $t5, logFirstRow	# t5 represent the bytes between  the display address  and the top left corner of the vehicle in a row
	add $t5, $t5, $t0	# t5 = address of the top left corner in that row;
	jal DrawAllocateOneRow	# Draw first row of vehicle
	
	# Draw second row of log
	la $t2, logRowSpace2	# address of the row array which stores the position of logs in the 2nd row
	lw $t5, logSecondRow	# t5 represent the bytes between  the display address  and the top left corner of the log in a row
	add $t5, $t5, $t0	# t5 = address of the top left corner in that row;
	jal DrawAllocateOneRow	# Draw first row of vehicle
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# Draw vehicle/log done; back to DrawBackground
	
DrawAllocateOneRow:	# Draw one row of vehicle/row
	add $t9, $zero, $zero	# t9 initialize i to 0
	addi $t8, $zero, 508	# t8 stores 508	(0-508 hsa 512 numbers, draw 512 times)
DrawAllocateOneRowLoop:	# draw the array into the targeted place in memory
	#  (i <= 508): $t5 + i = vehicleRowSpace[i]; i += 4
	# t9 = i;   t8 = 508;   t2 = address of the array storing where vehicles/logs are
	bgt $t9, $t8, DrawAllocateOneRowEnd
	add $t7, $t2, $t9	# t7 stores address of vehicleRowSpace[i]
	lw $t3, 0($t7)		# t3 = vehicleRowSpace[i]
	add $t6, $t5, $t9	# t6 stores address of t5 + i
	sw $t3, 0($t6)		# store vehicleRowSpace[i] into (t6 = t5 + i)

	addi $t9, $t9, 4	# i += 4
	j DrawAllocateOneRowLoop
DrawAllocateOneRowEnd:
	jr $ra	# Back to DrawVehicleLog

# Part2: sleep and repaint at 60Hz
Sleep:
	li $v0, 32
 	lw $a0, 0($sp)
	addi $sp, $sp, 4
 	syscall
 	jr $ra
 
# Part3: update location of vehicles/logs
UpdateVehicleLogLocation: # main function for update vehicle/log location
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store returning address to main into stack
	
	# Move the first row of vehicles & 2nd row of logs right
	la $a0, vehicleRowSpace1	# store the address of vehicleRowSpace1
	jal UpdateMoveToRight	# every pixel move to right
	
	la $a0, logRowSpace2	# store the address of logRowSpace2
	jal UpdateMoveToRight	# every pixel move to right
	
	# Move the 2nd row of vehicles & 1st row of logs right
	la $a0, vehicleRowSpace2	# store the initial address of vehicleRowSpace2
	jal UpdateMoveToLeft
	
	la $a0, logRowSpace1	# store the initial address of logRowSpace1
	jal UpdateMoveToLeft
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# UpdateVehicleLogLocation done; back to main
	
UpdateMoveToRight:
	addi $t1, $a0, 508	# the address of the last element (initial address a0 + 508)
	lw $a1, 0($t1)		# a1 holds the value of the last element
	j UpdateMoveToRightLoop
UpdateMoveToRightLoop:	# right shift
	# a0 = initial address;  t1 = last address;   $a1 = value in last address
	# while (last address != initial address): last address value = (last address-4) value;   last address -= 4
	beq $t1, $a0, AssignFirstToLeft # the address becomes the first element of the array, need to assign to the last element
	addi $t2, $t1, -4	# t2 = address at (last address - 4)
	lw $t3, 0($t2)		# t3 = value at (last address - 4)
	sw $t3, 0($t1)		# store t3 into t1 (last address)
	addi $t1, $t1, -4	# last address -=  4
	j UpdateMoveToRightLoop
AssignFirstToLeft:	# assign the first element = the last element
	sw $a1, 0($a0)
	jr $ra	# back to UpdateVehicleLogLocation
	
UpdateMoveToLeft:
	addi $t1, $a0, 508	# the address of the last element (initial address a0 + 508)
	lw $a1, 0($a0)		# a1 holds the value of the first element
UpdateMoveToLeftLoop:	# shift the array left
	# a0 = initial address;  t1 = last address;   $a1 = value in first address
	# while (last address != initial address): initial address value = (initial address+4) value;   initial address += 4
	beq $t1, $a0, AssignLastToFirst # the address becomes the first element of the array, need to assign to the last element
	addi $t2, $a0, 4	# t2 = address at (initial address + 4)
	lw $t3, 0($t2)		# t3 = value at (last address + 4)
	sw $t3, 0($a0)		# store t3 into t1 (first address)
	addi $a0, $a0, 4	# first address +=  4
	j UpdateMoveToLeftLoop
AssignLastToFirst:	# assign the last element = the first element
	sw $a1, 0($t1)
	jr $ra	# back to UpdateVehicleLogLocation

# Part4: check keyboard and update location of the frog
CheckKeyboardPress:
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store returning address to main into stack
	
	lw $t8, 0xffff0000	# checks if there's a keyboard being pressed
	beq $t8, 1, RespondToInput
	jr $ra	# no input, back to main

RespondToInput:
	lw $t2, 0xffff0004	# load the ascii of the pressed key
 	beq $t2, 0x61, RespondToA
 	beq $t2, 0x73, RespondToS
 	beq $t2, 0x64, RespondToD
 	beq $t2, 0x77, RespondToW
 
RespondToA:	# user moves the frog to left
	lw $t1, frogX	# t1 stores frog x value
	la $t2, frogX	# t2 stores the address storing frog x value
	addi $t1, $t1, -1	# frog x - 4
	beq $t1, -4, WrapToRight
	j UpdateFrogX
WrapToRight:	# if frog goes out of range on left
	addi $t1, $zero, 28
	j UpdateFrogX

RespondToD:	# frog moves right
	lw $t1, frogX	# t1 stores frog x value
	la $t2, frogX	# t2 stores the address storing frog x value
	addi $t1, $t1, 1
	beq $t1, 32, WrapToLeft	# goes out of range
	j UpdateFrogX
WrapToLeft:	# if frog goes out of range on right
	addi $t1, $zero, 0
	j UpdateFrogX
	
UpdateFrogX:	# save the updated X
	sw $t1, 0($t2)	# store the new frog x into t2
	
	# draw the new frog according to keyboard input
	jal DrawBackground
	jal DrawFrog
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to main
	
RespondToS:	# frog moves down
	lw $t1, frogY	# t1 stores frog x value
	la $t2, frogY	# t2 stores the address storing frog y value
	addi $t1, $t1, 4
	j UpdateFrogY

RespondToW:	# frog moves up
	lw $t1, frogY	# t1 stores frog x value
	la $t2, frogY	# t2 stores the address storing frog y value
	addi $t1, $t1, -4
	j UpdateFrogY
	
UpdateFrogY:
	sw $t1, 0($t2)	
	
	# draw the new frog according to keyboard input
	jal DrawBackground
	jal DrawFrog
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to main

# Part 5: Check collision
CheckCollision:
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address to main into stack
	
	lw $t0, frogX
	lw $t1, frogY
	
	addi $t2, $zero, 4
	addi $t3, $zero, 12
	mul $a1, $t2, $t0	# a1 = 4x, this is the distance between that line and the frog's leftmost x value
	add $a2, $a1, $t3	# a2 = 4x (a1) + 12 (t3), this is the distance between that line and the frog's rightmost x value
	
	beq $t1, 24, GetVehicleRowSpace2	# Get the vehicleRowSpace2 as parameter
	beq $t1, 20, GetVehicleRowSpace1
	beq $t1, 12, GetLogRowSpace2
	beq $t1, 8, GetLogRowSpace1
	beq $t1, 4, GetGoalRowSpace2
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# in safe/goal/start region, won't collide, go back to main

GetVehicleRowSpace2:	# if frog in vehicle row 2
	la $a0, vehicleRowSpace2	# a0 = address of vehicleRowSpace2
	lw $a3, vehicleColor	# a3 = vehicleColor
	j CheckVehicleLogCollision

GetVehicleRowSpace1:	# if frog in vehicle row 1
	la $a0, vehicleRowSpace1	# a0 = address of vehicleRowSpace1
	lw $a3, vehicleColor	# a3 = vehicleColor
	j CheckVehicleLogCollision

GetLogRowSpace2:	# if frog in log row 2
	la $a0, logRowSpace2	# a0 = address of logRowSpace2
	lw $a3, waterColor	# a3 = waterColor
	j CheckVehicleLogCollision

GetLogRowSpace1:	# if frog in log row 1
	la $a0, logRowSpace1	# a0 = address of logRowSpace1
	lw $a3, waterColor	# a3 = waterColor
	j CheckVehicleLogCollision

GetGoalRowSpace2:
	la $a0, goalRowSpace2	# a0 = address of goalRowSpace2
	lw $a3, emptyGoalHoleColor	# a3 = emptyGoalHoleColor
	j CheckGoalHoleCollision
	
CheckVehicleLogCollision:
	# a0 = vehicle/ logRowSpace 1 or 2;   a1 = initial + 4x (frog's left address in the array);   a2 = initial + 4x + 12, right address
	# a3 = vehicle/water Color (color that should not touch)
	add $a1, $a1, $a0	# a1 = initial + 4x (a1), the frog's left address in the array
	add $a2, $a2, $a0	# a2 = initial + 4x + 12 (a1), the frog's left address in the array
	
	lw $t9, 0($a1)	# t9 hold the value at initial + 4x
	lw $t8, 0($a2)	# t8 hold the value at iniital + 4x + 12
	beq $t9, $a3, CollideTrue	# if t9 hold vehicleColor, i.e. collide
	beq $t8, $a3, CollideTrue
	
	# no collision + in road region, back to main
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

CheckGoalHoleCollision:
	# parameter:
	# $a0 = goalRowSpace2 address;   $a3 = emptyGoalHoleColor
	add $a1, $a1, $a0	# a1 = initial + 4x (a1), the frog's left address in the array
	add $a2, $a2, $a0	# a2 = initial + 4x + 12 (a1), the frog's left address in the array
	
	lw $t9, 0($a1)	# t9 hold the value at initial + 4x
	lw $t8, 0($a2)	# t8 hold the value at iniital + 4x + 12
	bne $t9, $a3, GoalHoleNotCollide	# if t9 hold empty hole, i.e. collide
	bne $t8, $a3, GoalHoleNotCollide
	j SuccessState
GoalHoleNotCollide:
	# back to main
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# no collide, back to main

CollideTrue:	# decrease lives and print the remaining lives
	la $t9, lives	# lives address
	lw $t8, lives	# lives value
	subi $t8, $t8, 1	# decrease lives by 1, indeed collide
	sw $t8, 0($t9)	# save updated lives
	
	# print new live left text
	li $v0, 4
	la $a0, livesText
	syscall
	
	# print the new lives into the message box
	li $v0, 1
	lw $a0, lives
	syscall
	
	# print new line
	li $v0, 4
	la $a0, newline
	syscall
	
	# sleep for half a second
	li $a0, 800
	addi $sp, $sp, -4
	sw $a0, 0($sp)	
	jal Sleep
	
	# present frog death animation
	j DeathAnimation

SuccessState: # the frog reaches an empty goal hole
	# this function 
	# - increment GoalHoleFilled; increment score; update new sleepTime
	# - fills the empty hole  by reallocating goal region with frog color
	# - redraw frog at start state
	
	# sleep for 0.8 second (to show the frog indeed collides with the empty hole)
	li $a0, 800
	addi $sp, $sp, -4
	sw $a0, 0($sp)		# store time for sleeping into the stack
	jal Sleep
	
	# increment GoalHoleFilled
	la $t0, GoalHoleFilled	# $t0 = address of GoalHoleFilled
	lw $t1, GoalHoleFilled	# $t1 = value of GoalHoleFilled
	addi $t1, $t1, 1	# GoalHoleFilled += 1
	sw $t1, 0($t0)		# save the new GoalHoleFilled into $t0
	
	# score += 1
	la $t0, score
	lw $t1, score
	addi $t1, $t1, 1
	sw $t1, 0($t0)
	
	j CheckDecreaseSleepTime

CheckDecreaseSleepTime:
	# sleep time decreases if > 400
	la $t2, sleepTime	# address of sleepTime
	lw $t3, sleepTime	# value of sleepTime
	bgt $t3, 400, DecreaseSleepTime
	
	# sleep time <= 400, no need to decrease
	j FillEmptyGoalHole

DecreaseSleepTime:
	addi $t3, $t3, -150	# sleep time decreases
	sw $t3, ($t2)		# save the new sleep time 
	
	j FillEmptyGoalHole

FillEmptyGoalHole:
	# Fill the empty hole in goal region by reallocating
	lw $a0, frogX
	addi $t1, $zero, 4
	mul $a0, $a0, $t1	# $a0 store the x-coordinate * 5
	
	lw $a1, frogColor	# the frog color, which is used to fill the empty hole
	jal AllocateOneGoalHole	# reallocate
	
	# redraw the background together with new score
	jal DrawBackground	# this steps fills the empty hole
	
	# if all empty holes in goal region is filled;
	lw $t0, GoalHoleFilled
	beq $t0, 3, CheckLevel
	
	# redraw the frog at start position
	j RenewFrog

CheckLevel:
	# know: all 3 empty holes in one level being filled up, i.e. this level is completed
	# function: 
	#	renew lives
	#	renew GoalHoleFilled = 0 (no holes being filled up);    
	# 	check if already completes all levels, trigger win; otherwise, increase levelCompleted  &  call renewObjects
	
	# renew lives = 3
	la $t0, lives
	addi $t1, $zero, 3
	sw $t1, ($t0)
	
	# renew GoalHoleFilled to 0 in the next level
	la $t0, GoalHoleFilled	
	addi $t1, $zero, 0
	sw $t1, ($t0)
	
	# increase levelCompleted
	la $t2, levelCompleted
	lw $t3, levelCompleted
	addi $t3, $t3, 1
	sw $t3, ($t2)
	
	# get levelCompleted;  win if levelCompleted = 2
	beq $t3, 2, Win
	
	j RenewObjectsAsLevelIncrease

RenewObjectsAsLevelIncrease:
	# functions:
	#	renew vehicle/log allocating space
	#	increase vehicle, decrease log Length
	#	renew frog's position
	#	restart
	
	# renew vehicle/log allocating space
	la $t0, vehicleRowSpace1
	li $t1, 0
	lw $a0, roadColor
	jal DrawBackgroundTemplate
	
	la $t0, vehicleRowSpace2
	li $t1, 0
	lw $a0, roadColor
	jal DrawBackgroundTemplate
	
	la $t0, logRowSpace1
	li $t1, 0
	lw $a0, waterColor
	jal DrawBackgroundTemplate
	
	la $t0, logRowSpace2
	li $t1, 0
	lw $a0, waterColor
	jal DrawBackgroundTemplate
	
	# incrase vehicle length; decrease log length
	la $t4, vehicleLength
	lw $t5, vehicleLength
	addi $t5, $t5, 4
	sw $t5, ($t4)
	
	la $t6, logLength
	lw $t7, logLength
	addi $t7, $t7, -4
	sw $t7, ($t6)
	
	# renew frog position
	la $t0, frogX	# t0 stores the address storing frog x value
	addi $t2, $zero, 12	# initial x value of frog
	sw $t2, 0($t0)	# store 12 into t0
	
	la $t1, frogY	# t1 stores the address storing frog y value
	addi $t3, $zero, 28
	sw $t3, 0($t1)
	
	
	j main	# restart
	

DeathAnimation:
	# only frog's four corners are left; other part disappear
	# After death animation, renew frog
	
	# draw background with no frog
	jal DrawBackground	
	
	# draw dead state
	jal DrawDeadFrog
	
	# check if all lives are used up
	lw $t0, lives
	beq $t0, 0, Dead	# if loses 3 times, end the game
	
	# sleep for one second
	li $a0, 1000	# time for sleeping: 1s
	addi $sp, $sp, -4
	sw $a0, 0($sp)		# store time for sleeping into the stack
	jal Sleep
	
	# redraw the background without frog
	jal DrawBackground
	
	# redraw the new frog
	j RenewFrog	# frog back to start position, this method goes back to main

DrawDeadFrog:
	addi $sp, $sp, -4
	sw $ra, 0($sp)		# store the returning address to DeathAnimation into stack
	
	jal GetFrogLeftCornerAddress # $t5 stores the frog's top left corner's address
	lw $t1, frogColor	# t1 stores frog color
	
	# draw t1 (color) at t5
	sw $t1, 0($t5)
	sw $t1, 12($t5)
	sw $t1, 384($t5)
	sw $t1, 396($t5)
	
	lw $ra, 0($sp)	# remove the final returning address from stack
	addi $sp, $sp, 4
	jr $ra	# Back to DeathAnimation
	
RenewFrog:
	# update frog position back to start state   and   goes back to main
	la $t0, frogX	# t0 stores the address storing frog x value
	addi $t2, $zero, 12	# initial x value of frog
	sw $t2, 0($t0)	# store 12 into t0
	
	la $t1, frogY	# t1 stores the address storing frog y value
	addi $t3, $zero, 28
	sw $t3, 0($t1)
	
	jal DrawFrog		# draw the new frog at start position
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	# back to main
	
Dead:
	jal DrawBackground
	
	# print dead message
	li $v0, 4
	la $a0, deadText
	syscall
	
	# print new line
	li $v0, 4
	la $a0, newline
	syscall
	
 	j Exit
 
 Win:	# All 2 levels completed
 	# print win message
	li $v0, 4
	la $a0, winText
	syscall
	
	# print new line
	li $v0, 4
	la $a0, newline
	syscall
	
	j Exit
 
 Exit:
 	# end text
 	li $v0, 4
	la $a0, endText
	syscall
	
	# print new line
	li $v0, 4
	la $a0, newline
	syscall
	
  	li $v0, 10	# terminate the program gracefully
 	syscall







