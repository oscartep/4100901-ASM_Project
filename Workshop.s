
    .section .text
    .syntax unified
    .thumb
    .global main
    .global init_led
    .global init_systick
    .global SysTick_Handler
    .global init_button
    .global software_reset

// --- Definiciones de registros principales ----------------------------------
    .equ RCC_BASE,       0x40021000         
    .equ RCC_AHB2ENR,    RCC_BASE + 0x4C    
    .equ GPIOA_BASE,     0x48000000         
    .equ GPIOC_BASE,     0x48000800         
    .equ GPIOA_MODER,    GPIOA_BASE + 0x00  
    .equ GPIOA_ODR,      GPIOA_BASE + 0x14  
    .equ GPIOC_MODER,    GPIOC_BASE + 0x00  
    .equ GPIOC_IDR,      GPIOC_BASE + 0x10  
    .equ LD2_PIN,        5                  
    .equ B1_PIN,         13                 
    .equ SYST_CSR,       0xE000E010         
    .equ SYST_RVR,       0xE000E014         
    .equ HSI_FREQ,       4000000            

// --- Variable global para contador de tiempo ------------------------------
    .data
    contador: .word 0

    .text
main:
    bl init_led
    bl init_button
    bl init_systick

loop:
    wfi                           @ Espera interrupciones
    b loop

// --- Inicialización de PA5 como salida (LED) ---------------------------------
init_led:
    movw  r0, #:lower16:RCC_AHB2ENR
    movt  r0, #:upper16:RCC_AHB2ENR
    ldr   r1, [r0]
    orr   r1, r1, #(1 << 0)        @ Habilitar reloj de GPIOA
    str   r1, [r0]

    movw  r0, #:lower16:GPIOA_MODER
    movt  r0, #:upper16:GPIOA_MODER
    ldr   r1, [r0]
    bic   r1, r1, #(0b11 << (LD2_PIN * 2))
    orr   r1, r1, #(0b01 << (LD2_PIN * 2)) @ PA5 como salida
    str   r1, [r0]
    bx    lr

// --- Inicialización de PC13 como entrada (Botón B1) --------------------------
init_button:
    movw  r0, #:lower16:RCC_AHB2ENR
    movt  r0, #:upper16:RCC_AHB2ENR
    ldr   r1, [r0]
    orr   r1, r1, #(1 << 2)        @ Habilitar reloj de GPIOC
    str   r1, [r0]

    movw  r0, #:lower16:GPIOC_MODER
    movt  r0, #:upper16:GPIOC_MODER
    ldr   r1, [r0]
    bic   r1, r1, #(0b11 << (B1_PIN * 2)) @ PC13 como entrada
    str   r1, [r0]
    bx    lr

// --- Inicialización de SysTick a 10ms -----------------------------------
init_systick:
    movw  r0, #:lower16:SYST_RVR
    movt  r0, #:upper16:SYST_RVR
    movw  r1, #:lower16:40000        @ 4MHz/100 = 40000 ciclos para 10ms
    movt  r1, #:upper16:0
    subs  r1, r1, #1
    str   r1, [r0]

    movw  r0, #:lower16:SYST_CSR
    movt  r0, #:upper16:SYST_CSR
    movs  r1, #(1 << 0)|(1 << 1)|(1 << 2)  @ ENABLE | TICKINT | CLKSOURCE
    str   r1, [r0]
    bx    lr

// --- Manejador de interrupciones SysTick -------------------------------------
    .thumb_func
SysTick_Handler:
    @ Leer el estado del botón
    movw  r0, #:lower16:GPIOC_IDR
    movt  r0, #:upper16:GPIOC_IDR
    ldr   r1, [r0]
    tst   r1, #(1 << B1_PIN)      @ Comprobar si PC13 está a 0 (botón presionado)
    beq   boton_presionado        @ Si botón presionado (activo bajo), ir a boton_presionado

    b rcontador               @ Si no presionado, verificar contador

boton_presionado:
    movw  r0, #:lower16:contador
    movt  r0, #:upper16:contador
    ldr   r2, [r0]
    cmp   r2, #0
    bne   rcontador            @ Si ya está contando, no hacer nada

    movs  r1, #200                 @ Cargar 200 ticks (200 x 10ms = 2 segundos)
    str   r1, [r0]

    movw  r0, #:lower16:GPIOA_ODR
    movt  r0, #:upper16:GPIOA_ODR
    ldr   r1, [r0]
    orr   r1, r1, #(1 << LD2_PIN)  @ Enciende el LED
    str   r1, [r0]
    bx    lr

rcontador:
    movw  r0, #:lower16:contador
    movt  r0, #:upper16:contador
    ldr   r1, [r0]
    cmp   r1, #0
    beq   apagar_led               @ Si contador = 0, apagar LED
    subs  r1, r1, #1
    str   r1, [r0]
    bx    lr

apagar_led:
    movw  r0, #:lower16:GPIOA_ODR
    movt  r0, #:upper16:GPIOA_ODR
    ldr   r1, [r0]
    bic   r1, r1, #(1 << LD2_PIN)  @ Apaga el LED
    str   r1, [r0]
    bx    lr
