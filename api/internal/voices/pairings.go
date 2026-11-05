package voices

import (
	"context"
	"crypto/rand"
	"database/sql"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/lioilsources/hajanek/api/internal/db"
)

const (
	// PairingTTL is how long a pairing code can be claimed.
	PairingTTL = 10 * time.Minute
	// pairingKeep is how long an expired or claimed row is kept so that the
	// TV still sees "claimed"; codes in kept rows are not reissued.
	pairingKeep = 24 * time.Hour
)

var ErrSelfClaim = errors.New("cannot claim your own pairing code")

type PairingStatus string

const (
	PairingPending PairingStatus = "pending"
	PairingClaimed PairingStatus = "claimed"
)

// Pairing is the public view of a pairing code.
type Pairing struct {
	Code      string        `json:"code"`
	Status    PairingStatus `json:"status"`
	ExpiresAt time.Time     `json:"expires_at"`
}

// IsPairingCode reports whether c is exactly six ASCII digits.
func IsPairingCode(c string) bool {
	if len(c) != 6 {
		return false
	}
	for i := range len(c) {
		if c[i] < '0' || c[i] > '9' {
			return false
		}
	}
	return true
}

func newPairingCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// CreatePairing issues a new code for deviceID (the TV), replacing any
// previous one.
func (s *Store) CreatePairing(ctx context.Context, deviceID string) (Pairing, error) {
	var out Pairing
	err := s.inTx(ctx, func(q *db.Queries) error {
		now := s.Now()
		if err := q.DeleteStalePairings(ctx, now.Add(-pairingKeep).UnixMilli()); err != nil {
			return err
		}
		if err := q.DeleteDevicePairing(ctx, deviceID); err != nil {
			return err
		}
		for range 20 {
			code, err := newPairingCode()
			if err != nil {
				return err
			}
			n, err := q.PairingCodeTaken(ctx, code)
			if err != nil {
				return err
			}
			if n > 0 {
				continue
			}
			exp := now.Add(PairingTTL).UnixMilli()
			if err := q.InsertPairing(ctx, db.InsertPairingParams{
				Code: code, DeviceID: deviceID, CreatedAt: now.UnixMilli(), ExpiresAt: exp,
			}); err != nil {
				return err
			}
			out = Pairing{Code: code, Status: PairingPending, ExpiresAt: msTime(exp)}
			return nil
		}
		return errors.New("no free pairing code")
	})
	return out, err
}

// PairingStatusFor returns the state of code for the device that created
// it. Unknown codes, codes of other devices and expired unclaimed codes
// are ErrNotFound.
func (s *Store) PairingStatusFor(ctx context.Context, deviceID, code string) (Pairing, error) {
	if !IsPairingCode(code) {
		return Pairing{}, ErrNotFound
	}
	p, err := s.q.GetPairing(ctx, code)
	if errors.Is(err, sql.ErrNoRows) || (err == nil && p.DeviceID != deviceID) {
		return Pairing{}, ErrNotFound
	}
	if err != nil {
		return Pairing{}, err
	}
	out := Pairing{Code: p.Code, Status: PairingPending, ExpiresAt: msTime(p.ExpiresAt)}
	switch {
	case p.ClaimedAt.Valid:
		out.Status = PairingClaimed
	case p.ExpiresAt <= s.nowMs():
		return Pairing{}, ErrNotFound
	}
	return out, nil
}

// ClaimPairing moves the code's owner (the TV, with any voices it owns)
// into the household of claimerID and burns the code. Unknown, expired or
// already claimed codes are ErrNotFound; the owner claiming its own code
// is ErrSelfClaim (the code stays valid). The household the TV leaves is
// deleted when it has no devices left.
func (s *Store) ClaimPairing(ctx context.Context, claimerID, code string) error {
	if !IsPairingCode(code) {
		return ErrNotFound
	}
	return s.inTx(ctx, func(q *db.Queries) error {
		now := s.nowMs()
		p, err := q.GetPairing(ctx, code)
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}
		if p.ClaimedAt.Valid || p.ExpiresAt <= now {
			return ErrNotFound
		}
		if p.DeviceID == claimerID {
			return ErrSelfClaim
		}
		claimer, err := q.GetDevice(ctx, claimerID)
		if err != nil {
			return err
		}
		tv, err := q.GetDevice(ctx, p.DeviceID)
		if err != nil {
			return err
		}
		if tv.HouseholdID != claimer.HouseholdID {
			if err := q.SetDeviceHousehold(ctx, db.SetDeviceHouseholdParams{HouseholdID: claimer.HouseholdID, ID: tv.ID}); err != nil {
				return err
			}
			if err := q.DeleteHouseholdIfEmpty(ctx, tv.HouseholdID); err != nil {
				return err
			}
		}
		return q.MarkPairingClaimed(ctx, db.MarkPairingClaimedParams{
			ClaimedAt: sql.NullInt64{Int64: now, Valid: true}, ClaimedBy: nullStr(claimerID), Code: code,
		})
	})
}
