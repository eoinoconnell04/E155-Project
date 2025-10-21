import numpy as np
import plotly.graph_objects as go
import ipywidgets as widgets
from IPython.display import display

# -------------------------------
# 1. Helper functions
# -------------------------------
FS = 48000.0
Q = 0.707
MAX_CUT_DB = 15.0

def pot_to_gain_db(pot):
    """Map 0-1 pot to -15 to 0 dB cut"""
    return -MAX_CUT_DB * (1 - pot)

def db_to_amplitude(db):
    return 10 ** (db / 40)

# --- Low-shelf biquad ---
def low_shelf_coeffs(pot):
    gainDB = pot_to_gain_db(pot)
    A = db_to_amplitude(gainDB)
    w0 = 2 * np.pi * 400 / FS
    alpha = np.sin(w0)/(2*Q)
    cosw0 = np.cos(w0)

    b0 =    A*((A+1) - (A-1)*cosw0 + 2*np.sqrt(A)*alpha)
    b1 =  2*A*((A-1) - (A+1)*cosw0)
    b2 =    A*((A+1) - (A-1)*cosw0 - 2*np.sqrt(A)*alpha)
    a0 =        (A+1) + (A-1)*cosw0 + 2*np.sqrt(A)*alpha
    a1 =   -2*((A-1) + (A+1)*cosw0)
    a2 =        (A+1) + (A-1)*cosw0 - 2*np.sqrt(A)*alpha

    return np.array([b0, b1, b2])/a0, np.array([a1, a2])/a0

# --- Mid-peaking biquad ---
def mid_peaking_coeffs(pot):
    gainDB = pot_to_gain_db(pot)
    A = db_to_amplitude(gainDB)
    w0 = 2*np.pi*1000/FS
    alpha = np.sin(w0)/(2*Q)
    cosw0 = np.cos(w0)

    b0 = 1 + alpha*A
    b1 = -2*cosw0
    b2 = 1 - alpha*A
    a0 = 1 + alpha/A
    a1 = -2*cosw0
    a2 = 1 - alpha/A

    return np.array([b0, b1, b2])/a0, np.array([a1, a2])/a0

# --- High-shelf biquad ---
def high_shelf_coeffs(pot):
    gainDB = pot_to_gain_db(pot)
    A = db_to_amplitude(gainDB)
    w0 = 2*np.pi*2000/FS
    alpha = np.sin(w0)/(2*Q)
    cosw0 = np.cos(w0)

    b0 =    A*((A+1) + (A-1)*cosw0 + 2*np.sqrt(A)*alpha)
    b1 = -2*A*((A-1) + (A+1)*cosw0)
    b2 =    A*((A+1) + (A-1)*cosw0 - 2*np.sqrt(A)*alpha)
    a0 =        (A+1) - (A-1)*cosw0 + 2*np.sqrt(A)*alpha
    a1 =    2*((A-1) - (A+1)*cosw0)
    a2 =        (A+1) - (A-1)*cosw0 - 2*np.sqrt(A)*alpha

    return np.array([b0, b1, b2])/a0, np.array([a1, a2])/a0

# -------------------------------
# 2. Frequency response
# -------------------------------
def freqz(b, a, worN=512):
    """Simple freqz implementation"""
    w = np.logspace(np.log10(20), np.log10(FS/2), worN)
    z = np.exp(1j*2*np.pi*w/FS)
    h = (b[0] + b[1]/z + b[2]/z**2) / (1 + a[0]/z + a[1]/z**2)
    return w, h

def compute_total_response(low_pot, mid_pot, high_pot):
    bL, aL = low_shelf_coeffs(low_pot)
    bM, aM = mid_peaking_coeffs(mid_pot)
    bH, aH = high_shelf_coeffs(high_pot)

    w, hL = freqz(bL, aL)
    _, hM = freqz(bM, aM)
    _, hH = freqz(bH, aH)

    H_total = hL * hM * hH
    return w, 20*np.log10(np.abs(H_total))

# -------------------------------
# 3. Plotly interactive plot
# -------------------------------
def interactive_eq_plot():
    low_slider = widgets.FloatSlider(value=1.0, min=0.0, max=1.0, step=0.01, description='Low')
    mid_slider = widgets.FloatSlider(value=1.0, min=0.0, max=1.0, step=0.01, description='Mid')
    high_slider = widgets.FloatSlider(value=1.0, min=0.0, max=1.0, step=0.01, description='High')

    fig = go.FigureWidget()
    w, H = compute_total_response(low_slider.value, mid_slider.value, high_slider.value)
    trace = fig.add_scatter(x=w, y=H, mode='lines', name='EQ Response')
    fig.update_layout(
        xaxis=dict(type='log', title='Frequency (Hz)'),
        yaxis=dict(title='Magnitude (dB)', range=[-18, 3]),
        title='Interactive 3-Band EQ'
    )

    def update(change):
        w, H = compute_total_response(low_slider.value, mid_slider.value, high_slider.value)
        with fig.batch_update():
            fig.data[0].x = w
            fig.data[0].y = H

    low_slider.observe(update, names='value')
    mid_slider.observe(update, names='value')
    high_slider.observe(update, names='value')

    display(widgets.VBox([fig, low_slider, mid_slider, high_slider]))

# -------------------------------
# 4. Run if standalone
# -------------------------------
if __name__ == "__main__":
    interactive_eq_plot()
