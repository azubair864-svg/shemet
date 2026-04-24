/**
 * Racing Game Type Definitions
 */

export type RacingStatus = "BETTING" | "RACING" | "RESULT";

export interface RacingGameState {
    current_round_id: string;
    status: RacingStatus;
    next_phase_time: FirebaseFirestore.Timestamp;
    winner_car_id: string | null;
    participating_cars: string[];
    total_pool: number;
    vehicles?: Record<string, {
        odds: number;
        total_bets: number;
        speed_level: number;
    }>;
    history?: string[];
    created_at?: FirebaseFirestore.Timestamp;
    updated_at: FirebaseFirestore.Timestamp;
}

export interface BetData {
    user_id: string;
    car_id: string;
    amount: number;
    status: "PENDING" | "WON" | "LOST";
    payout?: number;
    timestamp: FirebaseFirestore.Timestamp;
}

export interface UserBetHistory {
    round_id: string;
    car_id: string;
    bet_amount: number;
    result: "WON" | "LOST";
    payout: number;
    timestamp: FirebaseFirestore.Timestamp;
}
