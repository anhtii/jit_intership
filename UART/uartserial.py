# fpga_uart_gui.py
# FPGA UART GUI with STRICT MODE SEPARATION
# Only process data according to selected mode

import serial
import serial.tools.list_ports
import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time
from datetime import datetime

BAUDRATE = 1_000_000


class FPGAUARTGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("FPGA UART Control Panel")
        self.root.geometry("540x560")

        self.ser = None
        self.running = False
        
        # Store last received values for each mode
        self.last_sw_value = 0x00
        self.last_temp_value = 0x00
        
        # Current displayed mode
        self.current_display_mode = "TEMP"  # TEMP, SW, or LED
        self.mode = tk.StringVar(value="TEMP")
        self.mode.trace('w', self.on_mode_changed)

        self.build_ui()

    def on_mode_changed(self, *args):
        """Called when mode is changed"""
        new_mode = self.mode.get()
        if new_mode != self.current_display_mode:
            self.current_display_mode = new_mode
            self.clear_displays()
            self.update_fpga_mode_display()
            self.log_msg(f"Display mode changed to: {new_mode}")

    def clear_displays(self):
        """Clear all displays"""
        self.sw_label.config(text="SW[7:0]: --")
        self.temp_label.config(text="Temperature: --.-- °C")
        self.rx_label.config(text="--")

    # ==================================================
    # UI
    # ==================================================
    def build_ui(self):
        # ---------- UART Connection ----------
        frame_top = ttk.LabelFrame(self.root, text="UART Connection")
        frame_top.pack(fill="x", padx=10, pady=5)

        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(
            frame_top,
            textvariable=self.port_var,
            values=self.list_ports(),
            width=15
        )
        self.port_combo.pack(side="left", padx=5, pady=5)

        ttk.Button(frame_top, text="Refresh", command=self.refresh_ports).pack(
            side="left", padx=5
        )

        self.btn_connect = ttk.Button(
            frame_top, text="Connect", command=self.toggle_connect
        )
        self.btn_connect.pack(side="left", padx=5)

        # ---------- MODE SELECT ----------
        frame_mode = ttk.LabelFrame(self.root, text="GUI Display Mode (Must match FPGA SW)")
        frame_mode.pack(fill="x", padx=10, pady=5)

        ttk.Radiobutton(frame_mode, text="TEMP (sw[8])",
                        variable=self.mode, value="TEMP",
                        command=self.on_temp_mode).pack(side="left", padx=5)
        ttk.Radiobutton(frame_mode, text="SW (sw[10])",
                        variable=self.mode, value="SW",
                        command=self.on_sw_mode).pack(side="left", padx=5)
        ttk.Radiobutton(frame_mode, text="LED (sw[9])",
                        variable=self.mode, value="LED",
                        command=self.on_led_mode).pack(side="left", padx=5)

        # ---------- FPGA Mode Status ----------
        frame_fpga_mode = ttk.LabelFrame(self.root, text="FPGA Mode Status")
        frame_fpga_mode.pack(fill="x", padx=10, pady=5)
        
        self.fpga_mode_label = ttk.Label(
            frame_fpga_mode,
            text="FPGA Mode: Unknown",
            font=("Consolas", 10, "bold")
        )
        self.fpga_mode_label.pack(pady=5)

        # ---------- Current Display ----------
        frame_display = ttk.LabelFrame(self.root, text="Currently Displaying")
        frame_display.pack(fill="x", padx=10, pady=5)
        
        self.display_mode_label = ttk.Label(
            frame_display,
            text="Mode: TEMP | Showing: Temperature",
            font=("Consolas", 10)
        )
        self.display_mode_label.pack(pady=5)

        # ---------- TX Control ----------
        frame_tx = ttk.LabelFrame(self.root, text="PC → FPGA (RAW HEX)")
        frame_tx.pack(fill="x", padx=10, pady=5)

        self.tx_entry = ttk.Entry(frame_tx, width=10)
        self.tx_entry.insert(0, "AA")
        self.tx_entry.pack(side="left", padx=5, pady=5)

        ttk.Button(frame_tx, text="Send HEX", command=self.send_hex).pack(
            side="left", padx=5
        )

        for val in [0x00, 0x55, 0xAA, 0xFF]:
            ttk.Button(
                frame_tx,
                text=f"0x{val:02X}",
                command=lambda v=val: self.send_byte(v)
            ).pack(side="left", padx=3)

        # ---------- RAW RX ----------
        frame_rx = ttk.LabelFrame(self.root, text="FPGA → PC (RAW BYTE)")
        frame_rx.pack(fill="x", padx=10, pady=5)

        self.rx_label = ttk.Label(
            frame_rx,
            text="--",
            font=("Consolas", 18)
        )
        self.rx_label.pack(pady=10)

        # ---------- SW VALUE Display ----------
        frame_sw = ttk.LabelFrame(self.root, text="SW Value (ONLY in SW mode)")
        frame_sw.pack(fill="x", padx=10, pady=5)

        self.sw_label = ttk.Label(
            frame_sw,
            text="SW[7:0]: --",
            font=("Consolas", 20)
        )
        self.sw_label.pack(pady=10)

        # ---------- Temperature Display ----------
        frame_temp = ttk.LabelFrame(self.root, text="Temperature (ONLY in TEMP mode)")
        frame_temp.pack(fill="x", padx=10, pady=5)

        self.temp_label = ttk.Label(
            frame_temp,
            text="Temperature: --.-- °C",
            font=("Consolas", 20)
        )
        self.temp_label.pack(pady=10)

        # ---------- Log ----------
        frame_log = ttk.LabelFrame(self.root, text="UART Log")
        frame_log.pack(fill="both", expand=True, padx=10, pady=5)

        self.log = tk.Text(frame_log, height=10, state="disabled")
        self.log.pack(fill="both", expand=True)

    def on_temp_mode(self):
        """Switch to TEMP mode display"""
        self.current_display_mode = "TEMP"
        self.update_fpga_mode_display()
        self.sw_label.config(text="SW[7:0]: --")
        self.log_msg("Switched to TEMP mode display")

    def on_sw_mode(self):
        """Switch to SW mode display"""
        self.current_display_mode = "SW"
        self.update_fpga_mode_display()
        self.temp_label.config(text="Temperature: --.-- °C")
        self.log_msg("Switched to SW mode display")

    def on_led_mode(self):
        """Switch to LED mode display"""
        self.current_display_mode = "LED"
        self.update_fpga_mode_display()
        self.sw_label.config(text="SW[7:0]: --")
        self.temp_label.config(text="Temperature: --.-- °C")
        self.log_msg("Switched to LED mode display")

    def update_fpga_mode_display(self):
        """Update FPGA mode status display"""
        mode = self.current_display_mode
        if mode == "TEMP":
            self.fpga_mode_label.config(
                text="FPGA Mode: TEMP (sw[10]=0, sw[9]=0, sw[8]=1)"
            )
            self.display_mode_label.config(
                text="Mode: TEMP | Showing: Temperature"
            )
        elif mode == "SW":
            self.fpga_mode_label.config(
                text="FPGA Mode: SW (sw[10]=1, sw[9]=0, sw[8]=0)"
            )
            self.display_mode_label.config(
                text="Mode: SW | Showing: SW[7:0] value"
            )
        elif mode == "LED":
            self.fpga_mode_label.config(
                text="FPGA Mode: LED (sw[10]=0, sw[9]=1, sw[8]=0)"
            )
            self.display_mode_label.config(
                text="Mode: LED | Showing: Nothing (RX only)"
            )

    # ==================================================
    # UART
    # ==================================================
    def list_ports(self):
        return [p.device for p in serial.tools.list_ports.comports()]

    def refresh_ports(self):
        self.port_combo["values"] = self.list_ports()

    def toggle_connect(self):
        if self.ser:
            self.disconnect()
        else:
            self.connect()

    def connect(self):
        try:
            self.ser = serial.Serial(
                self.port_var.get(),
                BAUDRATE,
                timeout=0.1
            )
            self.running = True
            threading.Thread(target=self.rx_thread, daemon=True).start()
            self.btn_connect.config(text="Disconnect")
            self.log_msg("Connected to " + self.port_var.get())
        except Exception as e:
            messagebox.showerror("UART Error", str(e))

    def disconnect(self):
        self.running = False
        if self.ser:
            self.ser.close()
            self.ser = None
        self.btn_connect.config(text="Connect")
        self.log_msg("Disconnected")

    # ==================================================
    # TX / RX
    # ==================================================
    def send_byte(self, value):
        if not self.ser:
            return
        self.ser.write(bytes([value & 0xFF]))
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        self.log_msg(f"[{timestamp}] TX -> 0x{value:02X}")

    def send_hex(self):
        try:
            value = int(self.tx_entry.get(), 16)
            self.send_byte(value)
        except ValueError:
            messagebox.showerror("Input Error", "Enter HEX value (00–FF)")

    def rx_thread(self):
        while self.running:
            if self.ser and self.ser.in_waiting:
                value = self.ser.read(1)[0]
                self.root.after(0, self.process_rx_data, value)
            time.sleep(0.01)

    # ==================================================
    # RX Processing - STRICT MODE SEPARATION
    # ==================================================
    def process_rx_data(self, value):
        """Process received data with strict mode separation"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        
        # Always show RAW byte
        self.rx_label.config(text=f"0x{value:02X}   {value:08b}")
        
        # Store value for current mode
        current_mode = self.current_display_mode
        
        if current_mode == "TEMP":
            # Store and process as temperature
            self.last_temp_value = value
            self.last_sw_value = 0x00  # Clear SW value
            
            # Convert to temperature
            temp_centi = value * 25
            temp_int = temp_centi // 100
            temp_frac = temp_centi % 100
            
            # Update display
            self.temp_label.config(
                text=f"Temperature: {temp_int}.{temp_frac:02d} °C"
            )
            self.sw_label.config(text="SW[7:0]: --")
            
            self.log_msg(
                f"[{timestamp}] [TEMP] RX <- 0x{value:02X} = {temp_int}.{temp_frac:02d} °C"
            )
            
        elif current_mode == "SW":
            # Store and process as SW value
            self.last_sw_value = value
            self.last_temp_value = 0x00  # Clear temp value
            
            # Update display
            self.sw_label.config(
                text=f"SW[7:0]: 0x{value:02X} ({value:08b})"
            )
            self.temp_label.config(text="Temperature: --.-- °C")
            
            self.log_msg(
                f"[{timestamp}] [SW] RX <- 0x{value:02X} = SW value"
            )
            
        elif current_mode == "LED":
            # Just log, don't display anything
            self.sw_label.config(text="SW[7:0]: --")
            self.temp_label.config(text="Temperature: --.-- °C")
            
            self.log_msg(
                f"[{timestamp}] [LED] RX <- 0x{value:02X}"
            )

    # ==================================================
    # Log
    # ==================================================
    def log_msg(self, msg):
        self.log.configure(state="normal")
        self.log.insert("end", msg + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")


# ==================================================
# Main
# ==================================================
if __name__ == "__main__":
    root = tk.Tk()
    app = FPGAUARTGUI(root)
    root.mainloop()