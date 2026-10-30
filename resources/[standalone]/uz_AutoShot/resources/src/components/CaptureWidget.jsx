/**
 * CaptureWidget — Capture progress indicator (top-right corner)
 *   Shows progress bar, current/total, pause/resume/cancel
 */

import React from 'react'

function KbdHint({ keys, label }) {
  return (
    <span className="flex items-center gap-1">
      <kbd style={{
        fontSize: 9, fontWeight: 600, fontFamily: 'monospace',
        padding: '2px 6px', borderRadius: 3,
        background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.06)',
        color: '#999', lineHeight: '13px',
      }}>
        {keys}
      </kbd>
      <span style={{ fontSize: 10, color: '#555' }}>{label}</span>
    </span>
  )
}

export function CaptureWidget({ progress, isPaused, onPause, onResume, onCancel }) {
  const pct = progress.total > 0 ? Math.round((progress.current / progress.total) * 100) : 0

  return (
    <div
      className="fixed right-5 top-5 z-[99999] glass rounded-xl overflow-hidden animate-enter"
      style={{
        width: 360,
        border: '1px solid rgba(255,255,255,0.06)',
        boxShadow: '0 8px 40px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.02)',
      }}
    >
      <div className="m-3 rounded-lg overflow-hidden"
        style={{ border: '1px solid rgba(255,255,255,0.04)', background: 'rgba(255,255,255,0.01)' }}>

        {/* Header */}
        <div style={{ padding: '18px 22px 12px' }}>
          {/* Title row */}
          <div className="flex items-center gap-2.5" style={{ marginBottom: 5 }}>
            <span
              className={isPaused ? '' : 'animate-pulse-dot'}
              style={{
                display: 'inline-block', width: 6, height: 6, borderRadius: '50%', flexShrink: 0,
                background: isPaused ? '#555' : '#f5f5f5',
                boxShadow: isPaused ? 'none' : '0 0 8px rgba(245,245,245,0.3)',
                transition: 'all 0.2s',
              }}
            />
            <h3 className="flex-1"
              style={{ fontSize: 18, fontWeight: 700, color: '#eee', letterSpacing: '-0.02em', lineHeight: '24px' }}>
              {isPaused ? 'Paused' : 'Capturing'}
            </h3>
            <span style={{
              fontSize: 18, fontWeight: 700, lineHeight: '24px', letterSpacing: '-0.02em',
              color: isPaused ? '#555' : '#eee',
              fontVariantNumeric: 'tabular-nums', transition: 'color 0.2s',
            }}>
              {pct}%
            </span>
          </div>

          {/* Subtitle */}
          <p style={{ fontSize: 11, fontWeight: 400, color: '#666', lineHeight: '16px' }}>
            {progress.category || 'Preparing...'}
            {progress.total > 0 && (
              <span style={{ color: '#444' }}>
                {' · '}
                <span style={{ fontVariantNumeric: 'tabular-nums', color: '#666' }}>
                  {progress.current} / {progress.total}
                </span>
              </span>
            )}
          </p>
        </div>

        {/* Divider */}
        <div style={{ height: 1, background: 'rgba(255,255,255,0.04)' }} />

        {/* Progress bar */}
        <div style={{ padding: '14px 22px' }}>
          <div style={{ height: 3, borderRadius: 99, background: 'rgba(255,255,255,0.04)', overflow: 'hidden' }}>
            <div style={{
              height: '100%', width: `${pct}%`, borderRadius: 99,
              background: isPaused ? '#555' : '#f5f5f5',
              transition: 'width 0.3s ease, background 0.2s',
            }} />
          </div>
        </div>

        {/* Divider */}
        <div style={{ height: 1, background: 'rgba(255,255,255,0.04)' }} />

        {/* Footer */}
        <div className="flex items-center justify-between" style={{ padding: '12px 22px 16px' }}>
          {isPaused ? (
            <>
              <button onClick={onCancel}
                className="transition-colors hover:bg-white/[0.03] focus-ring"
                style={{
                  width: 80, height: 28, fontSize: 10, fontWeight: 500, color: '#666',
                  background: 'transparent', border: '1px solid rgba(255,255,255,0.06)',
                  borderRadius: 5, cursor: 'pointer',
                }}>
                Cancel
              </button>
              <button onClick={onResume}
                className="transition-all focus-ring"
                style={{
                  width: 80, height: 28, fontSize: 10, fontWeight: 700,
                  background: '#f5f5f5', color: '#111',
                  border: '1px solid rgba(255,255,255,0.1)', borderRadius: 5,
                  cursor: 'pointer', boxShadow: '0 1px 8px rgba(255,255,255,0.08)',
                }}>
                Resume
              </button>
            </>
          ) : (
            <div className="flex items-center gap-3">
              <KbdHint keys="Space" label="Pause" />
              <span style={{ color: '#333', fontSize: 10 }}>·</span>
              <KbdHint keys="Esc" label="Cancel" />
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default CaptureWidget
