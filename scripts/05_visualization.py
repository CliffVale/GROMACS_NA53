#!/usr/bin/env python3
"""
05_visualization.py — Publication-Quality Analysis Plots
GROMACS_NA53

Generates plots for all analysis .xvg files.
Requires: numpy, matplotlib, seaborn (optional)

Usage: python 05_visualization.py [analysis_dir]
"""

import sys
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from pathlib import Path

# ─── Configuration ────────────────────────────────────────
ANALYSIS_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("../analysis")
FIGURES_DIR = Path("../results/figures")
FIGURES_DIR.mkdir(parents=True, exist_ok=True)

# Plot style
plt.rcParams.update({
    'font.size': 12,
    'font.family': 'serif',
    'axes.labelsize': 14,
    'axes.titlesize': 14,
    'xtick.labelsize': 11,
    'ytick.labelsize': 11,
    'legend.fontsize': 11,
    'figure.dpi': 300,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'axes.grid': True,
    'grid.alpha': 0.3,
})

COLORS = {
    'primary': '#2196F3',
    'secondary': '#FF9800',
    'accent': '#4CAF50',
    'warning': '#F44336',
    'dark': '#333333',
}


def read_xvg(filepath):
    """Read GROMACS .xvg file, skip comments and header."""
    x, y = [], []
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if line.startswith(('#', '@', '&')):
                continue
            parts = line.split()
            if len(parts) >= 2:
                try:
                    x.append(float(parts[0]))
                    y.append(float(parts[1]))
                except ValueError:
                    continue
    return np.array(x), np.array(y)


def read_xvg_multi(filepath):
    """Read GROMACS .xvg file with multiple columns."""
    data = []
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if line.startswith(('#', '@', '&')):
                continue
            parts = line.split()
            if len(parts) >= 2:
                try:
                    data.append([float(p) for p in parts])
                except ValueError:
                    continue
    return np.array(data) if data else np.array([])


def plot_rmsd():
    """Plot RMSD vs time."""
    xvg_file = ANALYSIS_DIR / "rmsd.xvg"
    if not xvg_file.exists():
        print(f"  ⚠️  {xvg_file} not found, skipping RMSD plot")
        return

    x, y = read_xvg(xvg_file)
    if len(x) == 0:
        return

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(x, y, color=COLORS['primary'], linewidth=0.8, alpha=0.7, label='RMSD')

    # Moving average (window = 1% of data)
    window = max(1, len(y) // 100)
    if window > 1:
        y_smooth = np.convolve(y, np.ones(window)/window, mode='valid')
        ax.plot(x[:len(y_smooth)], y_smooth, color=COLORS['warning'], linewidth=2, label='Moving Average')

    ax.set_xlabel('Time (ns)')
    ax.set_ylabel('RMSD (nm)')
    ax.set_title('Root Mean Square Deviation')
    ax.legend()

    # Add convergence indicator
    if len(y) > 100:
        last_quarter = y[-len(y)//4:]
        mean_last = np.mean(last_quarter)
        std_last = np.std(last_quarter)
        ax.axhline(y=mean_last, color=COLORS['accent'], linestyle='--', alpha=0.5)
        ax.fill_between(x[-len(y)//4:], mean_last - std_last, mean_last + std_last,
                       alpha=0.1, color=COLORS['accent'])

    plt.tight_layout()
    plt.savefig(FIGURES_DIR / "rmsd.png")
    plt.close()
    print(f"  ✓ RMSD plot saved")


def plot_rmsf():
    """Plot RMSF per residue."""
    xvg_file = ANALYSIS_DIR / "rmsf.xvg"
    if not xvg_file.exists():
        print(f"  ⚠️  {xvg_file} not found, skipping RMSF plot")
        return

    x, y = read_xvg(xvg_file)
    if len(x) == 0:
        return

    fig, ax = plt.subplots(figsize=(12, 5))
    ax.bar(x, y, color=COLORS['primary'], alpha=0.7, width=0.8)

    # Mark flexible regions (> mean + 2*std)
    threshold = np.mean(y) + 2 * np.std(y)
    flexible = x[y > threshold]
    if len(flexible) > 0:
        ax.scatter(flexible, y[y > threshold], color=COLORS['warning'], s=30, zorder=5,
                  label=f'Flexible (>{threshold:.2f} nm)')

    ax.set_xlabel('Residue Index')
    ax.set_ylabel('RMSF (nm)')
    ax.set_title('Root Mean Square Fluctuation per Residue')
    ax.legend()

    plt.tight_layout()
    plt.savefig(FIGURES_DIR / "rmsf.png")
    plt.close()
    print(f"  ✓ RMSF plot saved")


def plot_gyrate():
    """Plot radius of gyration vs time."""
    xvg_file = ANALYSIS_DIR / "gyrate.xvg"
    if not xvg_file.exists():
        print(f"  ⚠️  {xvg_file} not found, skipping Rg plot")
        return

    data = read_xvg_multi(xvg_file)
    if len(data) == 0:
        return

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(data[:, 0], data[:, 1], color=COLORS['primary'], linewidth=0.8, alpha=0.7, label='Rg')
    if data.shape[1] > 2:
        ax.plot(data[:, 0], data[:, 2], color=COLORS['secondary'], linewidth=0.8, alpha=0.5, label='Rg-X')
        ax.plot(data[:, 0], data[:, 3], color=COLORS['accent'], linewidth=0.8, alpha=0.5, label='Rg-Y')
        ax.plot(data[:, 0], data[:, 4], color=COLORS['warning'], linewidth=0.8, alpha=0.5, label='Rg-Z')

    ax.set_xlabel('Time (ns)')
    ax.set_ylabel('Rg (nm)')
    ax.set_title('Radius of Gyration')
    ax.legend()

    plt.tight_layout()
    plt.savefig(FIGURES_DIR / "gyrate.png")
    plt.close()
    print(f"  ✓ Radius of gyration plot saved")


def plot_hbonds():
    """Plot hydrogen bond count vs time."""
    xvg_file = ANALYSIS_DIR / "hbnum.xvg"
    if not xvg_file.exists():
        print(f"  ⚠️  {xvg_file} not found, skipping H-bond plot")
        return

    x, y = read_xvg(xvg_file)
    if len(x) == 0:
        return

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8), gridspec_kw={'height_ratios': [3, 1]})

    # Time series
    ax1.plot(x, y, color=COLORS['primary'], linewidth=0.5, alpha=0.5)
    window = max(1, len(y) // 100)
    if window > 1:
        y_smooth = np.convolve(y, np.ones(window)/window, mode='valid')
        ax1.plot(x[:len(y_smooth)], y_smooth, color=COLORS['warning'], linewidth=2, label='Moving Avg')
    ax1.set_ylabel('Number of H-bonds')
    ax1.set_title('Hydrogen Bond Analysis')
    ax1.legend()

    # Histogram
    ax2.hist(y, bins=50, color=COLORS['primary'], alpha=0.7, edgecolor='white')
    ax2.set_xlabel('Number of H-bonds')
    ax2.set_ylabel('Frequency')

    plt.tight_layout()
    plt.savefig(FIGURES_DIR / "hbonds.png")
    plt.close()
    print(f"  ✓ Hydrogen bond plot saved")


def plot_sasa():
    """Plot SASA vs time."""
    xvg_file = ANALYSIS_DIR / "sasa.xvg"
    if not xvg_file.exists():
        print(f"  ⚠️  {xvg_file} not found, skipping SASA plot")
        return

    x, y = read_xvg(xvg_file)
    if len(x) == 0:
        return

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(x, y, color=COLORS['primary'], linewidth=0.8, alpha=0.7)
    ax.set_xlabel('Time (ns)')
    ax.set_ylabel('SASA (nm²)')
    ax.set_title('Solvent Accessible Surface Area')

    plt.tight_layout()
    plt.savefig(FIGURES_DIR / "sasa.png")
    plt.close()
    print(f"  ✓ SASA plot saved")


def plot_energy():
    """Plot energy terms from production .edr."""
    energy_files = {
        'Temperature': 'energy_Temperature.xvg',
        'Pressure': 'energy_Pressure.xvg',
        'Density': 'energy_Density.xvg',
        'Potential': 'energy_Potential.xvg',
    }

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    axes = axes.flatten()

    for idx, (name, fname) in enumerate(energy_files.items()):
        xvg_file = ANALYSIS_DIR / fname
        if xvg_file.exists():
            x, y = read_xvg(xvg_file)
            if len(x) > 0:
                axes[idx].plot(x, y, color=COLORS['primary'], linewidth=0.5, alpha=0.5)
                window = max(1, len(y) // 50)
                if window > 1:
                    y_smooth = np.convolve(y, np.ones(window)/window, mode='valid')
                    axes[idx].plot(x[:len(y_smooth)], y_smooth, color=COLORS['warning'], linewidth=2)
                axes[idx].set_title(name)
                axes[idx].set_xlabel('Time (ns)')
        else:
            axes[idx].text(0.5, 0.5, f'{name}\n(Data not available)', ha='center', va='center',
                          transform=axes[idx].transAxes, fontsize=12)
            axes[idx].set_title(name)

    plt.suptitle('Production MD Energy Terms', fontsize=16, y=1.02)
    plt.tight_layout()
    plt.savefig(FIGURES_DIR / "energy_terms.png")
    plt.close()
    print(f"  ✓ Energy terms plot saved")


def plot_pca():
    """Plot PCA projection (PC1 vs PC2) and eigenvalues."""
    proj_file = ANALYSIS_DIR / "proj.xvg"
    eigenval_file = ANALYSIS_DIR / "eigenval.xvg"

    fig, axes = plt.subplots(1, 2, figsize=(14, 6))

    # Eigenvalue spectrum
    if eigenval_file.exists():
        data = read_xvg_multi(eigenval_file)
        if len(data) > 0:
            n_show = min(20, len(data))
            axes[0].bar(range(1, n_show + 1), data[:n_show, 1], color=COLORS['primary'], alpha=0.7)
            axes[0].set_xlabel('Principal Component')
            axes[0].set_ylabel('Eigenvalue')
            axes[0].set_title('PCA Eigenvalue Spectrum')

    # PC1 vs PC2 projection
    if proj_file.exists():
        data = read_xvg_multi(proj_file)
        if len(data) > 0 and data.shape[1] >= 3:
            scatter = axes[1].scatter(data[:, 1], data[:, 2], c=data[:, 0], cmap='viridis',
                                     s=5, alpha=0.5)
            plt.colorbar(scatter, ax=axes[1], label='Time (ps)')
            axes[1].set_xlabel('PC1')
            axes[1].set_ylabel('PC2')
            axes[1].set_title('Free Energy Landscape (PC1 vs PC2)')

    plt.tight_layout()
    plt.savefig(FIGURES_DIR / "pca.png")
    plt.close()
    print(f"  ✓ PCA plot saved")


def plot_summary_dashboard():
    """Generate a summary dashboard with all metrics."""
    fig = plt.figure(figsize=(20, 16))
    gs = gridspec.GridSpec(3, 3, hspace=0.4, wspace=0.35)

    plots = [
        ("rmsd.xvg", "RMSD (nm)", "Root Mean Square Deviation", 0, 0),
        ("rmsf.xvg", "RMSF (nm)", "Residue Fluctuation", 0, 1),
        ("gyrate.xvg", "Rg (nm)", "Radius of Gyration", 0, 2),
        ("hbnum.xvg", "H-bonds", "Hydrogen Bond Count", 1, 0),
        ("sasa.xvg", "SASA (nm²)", "Solvent Accessible Surface", 1, 1),
        ("energy_Temperature.xvg", "T (K)", "Temperature", 1, 2),
        ("energy_Pressure.xvg", "P (bar)", "Pressure", 2, 0),
        ("energy_Density.xvg", "ρ (kg/m³)", "Density", 2, 1),
    ]

    for fname, ylabel, title, row, col in plots:
        ax = fig.add_subplot(gs[row, col])
        xvg_file = ANALYSIS_DIR / fname
        if xvg_file.exists():
            data = read_xvg_multi(xvg_file)
            if len(data) > 0:
                y_col = 1 if data.shape[1] > 1 else 0
                ax.plot(data[:, 0], data[:, y_col], color=COLORS['primary'], linewidth=0.5, alpha=0.5)
                window = max(1, len(data[:, y_col]) // 100)
                if window > 1:
                    y_smooth = np.convolve(data[:, y_col], np.ones(window)/window, mode='valid')
                    ax.plot(data[:len(y_smooth), 0], y_smooth, color=COLORS['warning'], linewidth=2)
                ax.set_ylabel(ylabel)
        ax.set_title(title, fontweight='bold')

    # RMSF as bar plot in the last subplot
    ax = fig.add_subplot(gs[2, 2])
    xvg_file = ANALYSIS_DIR / "rmsf.xvg"
    if xvg_file.exists():
        x, y = read_xvg(xvg_file)
        if len(x) > 0:
            ax.bar(x, y, color=COLORS['primary'], alpha=0.7, width=0.8)
            ax.set_ylabel("RMSF (nm)")
            ax.set_title("Residue Fluctuation (Detail)", fontweight='bold')

    plt.suptitle('GROMACS_NA53: Production MD Summary Dashboard', fontsize=18, fontweight='bold', y=1.01)
    plt.savefig(FIGURES_DIR / "summary_dashboard.png")
    plt.close()
    print(f"  ✓ Summary dashboard saved")


# ─── Main ─────────────────────────────────────────────────
if __name__ == "__main__":
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  NA53 VISUALIZATION — Generating plots")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"  Analysis dir: {ANALYSIS_DIR}")
    print(f"  Figures dir:  {FIGURES_DIR}")

    plot_rmsd()
    plot_rmsf()
    plot_gyrate()
    plot_hbonds()
    plot_sasa()
    plot_energy()
    plot_pca()
    plot_summary_dashboard()

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  ALL PLOTS GENERATED")
    print("  Output directory:", FIGURES_DIR)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
