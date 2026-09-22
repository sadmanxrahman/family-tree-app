export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      app_config: {
        Row: {
          deleted_at: string | null
          key: string
          updated_at: string
          value: Json
        }
        Insert: {
          deleted_at?: string | null
          key: string
          updated_at?: string
          value: Json
        }
        Update: {
          deleted_at?: string | null
          key?: string
          updated_at?: string
          value?: Json
        }
        Relationships: []
      }
      app_users: {
        Row: {
          age_confirmed_at: string | null
          created_at: string
          deleted_at: string | null
          display_name: string | null
          id: string
          updated_at: string
        }
        Insert: {
          age_confirmed_at?: string | null
          created_at?: string
          deleted_at?: string | null
          display_name?: string | null
          id: string
          updated_at?: string
        }
        Update: {
          age_confirmed_at?: string | null
          created_at?: string
          deleted_at?: string | null
          display_name?: string | null
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      change_log: {
        Row: {
          action: string
          actor_user_id: string | null
          after: Json | null
          before: Json | null
          created_at: string
          deleted_at: string | null
          id: string
          reason: string | null
          row_id: string
          table_name: string
          tree_id: string
          undone_by_change_id: string | null
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          reason?: string | null
          row_id: string
          table_name: string
          tree_id: string
          undone_by_change_id?: string | null
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          reason?: string | null
          row_id?: string
          table_name?: string
          tree_id?: string
          undone_by_change_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "change_log_actor_user_id_fkey"
            columns: ["actor_user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "change_log_tree_id_fkey"
            columns: ["tree_id"]
            isOneToOne: false
            referencedRelation: "trees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "change_log_undone_by_change_id_fkey"
            columns: ["undone_by_change_id"]
            isOneToOne: false
            referencedRelation: "change_log"
            referencedColumns: ["id"]
          },
        ]
      }
      change_requests: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          person_id: string
          proposed_changes: Json
          requested_by: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["request_status"]
          tree_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          person_id: string
          proposed_changes: Json
          requested_by?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          tree_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          person_id?: string
          proposed_changes?: Json
          requested_by?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "change_requests_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "change_requests_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "change_requests_tree_id_person_id_fkey"
            columns: ["tree_id", "person_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      claims: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          invitation_id: string | null
          person_id: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["request_status"]
          tree_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          invitation_id?: string | null
          person_id: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          tree_id: string
          updated_at?: string
          user_id?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          invitation_id?: string | null
          person_id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          tree_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "claims_invitation_id_fkey"
            columns: ["invitation_id"]
            isOneToOne: false
            referencedRelation: "invitations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "claims_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "claims_tree_id_person_id_fkey"
            columns: ["tree_id", "person_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
          {
            foreignKeyName: "claims_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
        ]
      }
      comments: {
        Row: {
          author_user_id: string
          body: string
          created_at: string
          deleted_at: string | null
          id: string
          memory_id: string
          tree_id: string
          updated_at: string
        }
        Insert: {
          author_user_id?: string
          body: string
          created_at?: string
          deleted_at?: string | null
          id?: string
          memory_id: string
          tree_id: string
          updated_at?: string
        }
        Update: {
          author_user_id?: string
          body?: string
          created_at?: string
          deleted_at?: string | null
          id?: string
          memory_id?: string
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "comments_author_user_id_fkey"
            columns: ["author_user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_tree_id_memory_id_fkey"
            columns: ["tree_id", "memory_id"]
            isOneToOne: false
            referencedRelation: "memories"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      feed_events: {
        Row: {
          actor_user_id: string | null
          created_at: string
          deleted_at: string | null
          id: string
          kind: Database["public"]["Enums"]["feed_event_kind"]
          memory_id: string | null
          person_id: string | null
          tree_id: string
        }
        Insert: {
          actor_user_id?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          kind: Database["public"]["Enums"]["feed_event_kind"]
          memory_id?: string | null
          person_id?: string | null
          tree_id: string
        }
        Update: {
          actor_user_id?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["feed_event_kind"]
          memory_id?: string | null
          person_id?: string | null
          tree_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "feed_events_actor_user_id_fkey"
            columns: ["actor_user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "feed_events_tree_id_fkey"
            columns: ["tree_id"]
            isOneToOne: false
            referencedRelation: "trees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "feed_events_tree_id_memory_id_fkey"
            columns: ["tree_id", "memory_id"]
            isOneToOne: false
            referencedRelation: "memories"
            referencedColumns: ["tree_id", "id"]
          },
          {
            foreignKeyName: "feed_events_tree_id_person_id_fkey"
            columns: ["tree_id", "person_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      invitations: {
        Row: {
          created_at: string
          deleted_at: string | null
          expires_at: string
          id: string
          invited_by: string
          max_uses: number
          person_id: string | null
          revoked_at: string | null
          role: Database["public"]["Enums"]["tree_role"]
          token_hash: string
          tree_id: string
          updated_at: string
          use_count: number
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          expires_at: string
          id?: string
          invited_by: string
          max_uses?: number
          person_id?: string | null
          revoked_at?: string | null
          role?: Database["public"]["Enums"]["tree_role"]
          token_hash: string
          tree_id: string
          updated_at?: string
          use_count?: number
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          expires_at?: string
          id?: string
          invited_by?: string
          max_uses?: number
          person_id?: string | null
          revoked_at?: string | null
          role?: Database["public"]["Enums"]["tree_role"]
          token_hash?: string
          tree_id?: string
          updated_at?: string
          use_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "invitations_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_tree_id_fkey"
            columns: ["tree_id"]
            isOneToOne: false
            referencedRelation: "trees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_tree_id_person_id_fkey"
            columns: ["tree_id", "person_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      media_assets: {
        Row: {
          byte_size: number | null
          created_at: string
          created_by: string
          deleted_at: string | null
          duration_ms: number | null
          height: number | null
          id: string
          memory_id: string | null
          mime_type: string
          sort_order: number
          storage_path: string
          thumbnail_path: string | null
          tree_id: string
          updated_at: string
          width: number | null
        }
        Insert: {
          byte_size?: number | null
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          duration_ms?: number | null
          height?: number | null
          id?: string
          memory_id?: string | null
          mime_type: string
          sort_order?: number
          storage_path: string
          thumbnail_path?: string | null
          tree_id: string
          updated_at?: string
          width?: number | null
        }
        Update: {
          byte_size?: number | null
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          duration_ms?: number | null
          height?: number | null
          id?: string
          memory_id?: string | null
          mime_type?: string
          sort_order?: number
          storage_path?: string
          thumbnail_path?: string | null
          tree_id?: string
          updated_at?: string
          width?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "media_assets_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "media_assets_tree_id_fkey"
            columns: ["tree_id"]
            isOneToOne: false
            referencedRelation: "trees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "media_assets_tree_id_memory_id_fkey"
            columns: ["tree_id", "memory_id"]
            isOneToOne: false
            referencedRelation: "memories"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      memories: {
        Row: {
          body: string | null
          created_at: string
          created_by: string
          deleted_at: string | null
          id: string
          kind: Database["public"]["Enums"]["memory_kind"]
          memory_date: string | null
          memory_date_end: string | null
          memory_date_precision:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          place_id: string | null
          title: string | null
          tree_id: string
          updated_at: string
        }
        Insert: {
          body?: string | null
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          kind: Database["public"]["Enums"]["memory_kind"]
          memory_date?: string | null
          memory_date_end?: string | null
          memory_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          place_id?: string | null
          title?: string | null
          tree_id: string
          updated_at?: string
        }
        Update: {
          body?: string | null
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["memory_kind"]
          memory_date?: string | null
          memory_date_end?: string | null
          memory_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          place_id?: string | null
          title?: string | null
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "memories_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memories_tree_id_fkey"
            columns: ["tree_id"]
            isOneToOne: false
            referencedRelation: "trees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memories_tree_id_place_id_fkey"
            columns: ["tree_id", "place_id"]
            isOneToOne: false
            referencedRelation: "places"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      memory_people: {
        Row: {
          created_at: string
          created_by: string
          deleted_at: string | null
          id: string
          memory_id: string
          person_id: string
          tree_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          memory_id: string
          person_id: string
          tree_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          memory_id?: string
          person_id?: string
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "memory_people_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memory_people_tree_id_memory_id_fkey"
            columns: ["tree_id", "memory_id"]
            isOneToOne: false
            referencedRelation: "memories"
            referencedColumns: ["tree_id", "id"]
          },
          {
            foreignKeyName: "memory_people_tree_id_person_id_fkey"
            columns: ["tree_id", "person_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      notifications: {
        Row: {
          change_log_id: string | null
          change_request_id: string | null
          created_at: string
          deleted_at: string | null
          id: string
          kind: Database["public"]["Enums"]["notification_kind"]
          read_at: string | null
          recipient_user_id: string
          tree_id: string
        }
        Insert: {
          change_log_id?: string | null
          change_request_id?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          kind: Database["public"]["Enums"]["notification_kind"]
          read_at?: string | null
          recipient_user_id: string
          tree_id: string
        }
        Update: {
          change_log_id?: string | null
          change_request_id?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["notification_kind"]
          read_at?: string | null
          recipient_user_id?: string
          tree_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_change_log_id_fkey"
            columns: ["change_log_id"]
            isOneToOne: false
            referencedRelation: "change_log"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_change_request_id_fkey"
            columns: ["change_request_id"]
            isOneToOne: false
            referencedRelation: "change_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_recipient_user_id_fkey"
            columns: ["recipient_user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_tree_id_fkey"
            columns: ["tree_id"]
            isOneToOne: false
            referencedRelation: "trees"
            referencedColumns: ["id"]
          },
        ]
      }
      parent_child: {
        Row: {
          child_id: string
          created_at: string
          created_by: string
          deleted_at: string | null
          end_date: string | null
          end_date_end: string | null
          end_date_precision:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          id: string
          kind: Database["public"]["Enums"]["parent_child_kind"]
          parent_id: string
          start_date: string | null
          start_date_end: string | null
          start_date_precision:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          tree_id: string
          updated_at: string
        }
        Insert: {
          child_id: string
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          end_date?: string | null
          end_date_end?: string | null
          end_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          id?: string
          kind: Database["public"]["Enums"]["parent_child_kind"]
          parent_id: string
          start_date?: string | null
          start_date_end?: string | null
          start_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          tree_id: string
          updated_at?: string
        }
        Update: {
          child_id?: string
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          end_date?: string | null
          end_date_end?: string | null
          end_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          id?: string
          kind?: Database["public"]["Enums"]["parent_child_kind"]
          parent_id?: string
          start_date?: string | null
          start_date_end?: string | null
          start_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "parent_child_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "parent_child_tree_id_child_id_fkey"
            columns: ["tree_id", "child_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
          {
            foreignKeyName: "parent_child_tree_id_parent_id_fkey"
            columns: ["tree_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      person_names: {
        Row: {
          created_at: string
          created_by: string
          deleted_at: string | null
          id: string
          kind: Database["public"]["Enums"]["name_kind"]
          name: string
          person_id: string
          script: string | null
          tree_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["name_kind"]
          name: string
          person_id: string
          script?: string | null
          tree_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["name_kind"]
          name?: string
          person_id?: string
          script?: string | null
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "person_names_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "person_names_tree_id_person_id_fkey"
            columns: ["tree_id", "person_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      person_places: {
        Row: {
          created_at: string
          created_by: string
          deleted_at: string | null
          end_date: string | null
          end_date_end: string | null
          end_date_precision:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          id: string
          kind: Database["public"]["Enums"]["person_place_kind"]
          person_id: string
          place_id: string
          start_date: string | null
          start_date_end: string | null
          start_date_precision:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          tree_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          end_date?: string | null
          end_date_end?: string | null
          end_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          id?: string
          kind: Database["public"]["Enums"]["person_place_kind"]
          person_id: string
          place_id: string
          start_date?: string | null
          start_date_end?: string | null
          start_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          tree_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          end_date?: string | null
          end_date_end?: string | null
          end_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          id?: string
          kind?: Database["public"]["Enums"]["person_place_kind"]
          person_id?: string
          place_id?: string
          start_date?: string | null
          start_date_end?: string | null
          start_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "person_places_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "person_places_tree_id_person_id_fkey"
            columns: ["tree_id", "person_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
          {
            foreignKeyName: "person_places_tree_id_place_id_fkey"
            columns: ["tree_id", "place_id"]
            isOneToOne: false
            referencedRelation: "places"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
      persons: {
        Row: {
          birth_date: string | null
          birth_date_end: string | null
          birth_date_precision:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          birth_family_name: string | null
          claimed_by_user_id: string | null
          created_at: string
          created_by: string
          death_date: string | null
          death_date_end: string | null
          death_date_precision:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          deleted_at: string | null
          family_name: string | null
          gender: Database["public"]["Enums"]["person_gender"] | null
          given_names: string | null
          hidden_from_map: boolean
          id: string
          is_living: boolean
          profile_media_id: string | null
          tree_id: string
          updated_at: string
        }
        Insert: {
          birth_date?: string | null
          birth_date_end?: string | null
          birth_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          birth_family_name?: string | null
          claimed_by_user_id?: string | null
          created_at?: string
          created_by?: string
          death_date?: string | null
          death_date_end?: string | null
          death_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          deleted_at?: string | null
          family_name?: string | null
          gender?: Database["public"]["Enums"]["person_gender"] | null
          given_names?: string | null
          hidden_from_map?: boolean
          id?: string
          is_living?: boolean
          profile_media_id?: string | null
          tree_id: string
          updated_at?: string
        }
        Update: {
          birth_date?: string | null
          birth_date_end?: string | null
          birth_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          birth_family_name?: string | null
          claimed_by_user_id?: string | null
          created_at?: string
          created_by?: string
          death_date?: string | null
          death_date_end?: string | null
          death_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          deleted_at?: string | null
          family_name?: string | null
          gender?: Database["public"]["Enums"]["person_gender"] | null
          given_names?: string | null
          hidden_from_map?: boolean
          id?: string
          is_living?: boolean
          profile_media_id?: string | null
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "persons_claimed_by_user_id_fkey"
            columns: ["claimed_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "persons_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "persons_profile_media_fkey"
            columns: ["tree_id", "profile_media_id"]
            isOneToOne: false
            referencedRelation: "media_assets"
            referencedColumns: ["tree_id", "id"]
          },
          {
            foreignKeyName: "persons_tree_id_fkey"
            columns: ["tree_id"]
            isOneToOne: false
            referencedRelation: "trees"
            referencedColumns: ["id"]
          },
        ]
      }
      places: {
        Row: {
          canonical_place_id: string | null
          country_code: string | null
          created_at: string
          created_by: string
          deleted_at: string | null
          id: string
          latitude: number | null
          longitude: number | null
          name: string
          place_type: Database["public"]["Enums"]["place_type"]
          tree_id: string
          updated_at: string
        }
        Insert: {
          canonical_place_id?: string | null
          country_code?: string | null
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          name: string
          place_type?: Database["public"]["Enums"]["place_type"]
          tree_id: string
          updated_at?: string
        }
        Update: {
          canonical_place_id?: string | null
          country_code?: string | null
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          name?: string
          place_type?: Database["public"]["Enums"]["place_type"]
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "places_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "places_tree_id_fkey"
            columns: ["tree_id"]
            isOneToOne: false
            referencedRelation: "trees"
            referencedColumns: ["id"]
          },
        ]
      }
      reactions: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          kind: Database["public"]["Enums"]["reaction_kind"]
          memory_id: string
          tree_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          kind: Database["public"]["Enums"]["reaction_kind"]
          memory_id: string
          tree_id: string
          updated_at?: string
          user_id?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["reaction_kind"]
          memory_id?: string
          tree_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reactions_tree_id_memory_id_fkey"
            columns: ["tree_id", "memory_id"]
            isOneToOne: false
            referencedRelation: "memories"
            referencedColumns: ["tree_id", "id"]
          },
          {
            foreignKeyName: "reactions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
        ]
      }
      tree_members: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          invited_by: string | null
          role: Database["public"]["Enums"]["tree_role"]
          tree_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          invited_by?: string | null
          role?: Database["public"]["Enums"]["tree_role"]
          tree_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          invited_by?: string | null
          role?: Database["public"]["Enums"]["tree_role"]
          tree_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tree_members_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tree_members_tree_id_fkey"
            columns: ["tree_id"]
            isOneToOne: false
            referencedRelation: "trees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tree_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
        ]
      }
      trees: {
        Row: {
          created_at: string
          created_by: string
          deleted_at: string | null
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by: string
          deleted_at?: string | null
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "trees_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
        ]
      }
      unions: {
        Row: {
          created_at: string
          created_by: string
          deleted_at: string | null
          end_date: string | null
          end_date_end: string | null
          end_date_precision:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          id: string
          kind: Database["public"]["Enums"]["union_kind"]
          person_a_id: string
          person_b_id: string
          start_date: string | null
          start_date_end: string | null
          start_date_precision:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          status: Database["public"]["Enums"]["union_status"]
          tree_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          end_date?: string | null
          end_date_end?: string | null
          end_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          id?: string
          kind?: Database["public"]["Enums"]["union_kind"]
          person_a_id: string
          person_b_id: string
          start_date?: string | null
          start_date_end?: string | null
          start_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          status?: Database["public"]["Enums"]["union_status"]
          tree_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          end_date?: string | null
          end_date_end?: string | null
          end_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          id?: string
          kind?: Database["public"]["Enums"]["union_kind"]
          person_a_id?: string
          person_b_id?: string
          start_date?: string | null
          start_date_end?: string | null
          start_date_precision?:
            | Database["public"]["Enums"]["fuzzy_precision"]
            | null
          status?: Database["public"]["Enums"]["union_status"]
          tree_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "unions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "unions_tree_id_person_a_id_fkey"
            columns: ["tree_id", "person_a_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
          {
            foreignKeyName: "unions_tree_id_person_b_id_fkey"
            columns: ["tree_id", "person_b_id"]
            isOneToOne: false
            referencedRelation: "persons"
            referencedColumns: ["tree_id", "id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_invitation: { Args: { p_token: string }; Returns: string }
      can_edit_person: { Args: { p_person_id: string }; Returns: boolean }
      can_edit_tree: { Args: { p_tree_id: string }; Returns: boolean }
      change_request_fields_valid: {
        Args: { p_changes: Json }
        Returns: boolean
      }
      confirm_adult: { Args: never; Returns: undefined }
      create_invitation: {
        Args: {
          p_max_uses?: number
          p_person_id?: string
          p_role?: Database["public"]["Enums"]["tree_role"]
          p_tree_id: string
          p_valid_days?: number
        }
        Returns: string
      }
      create_tree: { Args: { p_name: string }; Returns: string }
      delete_tree: { Args: { p_tree_id: string }; Returns: undefined }
      fuzzy_date_is_valid: {
        Args: {
          p_date: string
          p_end: string
          p_precision: Database["public"]["Enums"]["fuzzy_precision"]
        }
        Returns: boolean
      }
      fuzzy_date_json: {
        Args: {
          p_date: string
          p_end: string
          p_precision: Database["public"]["Enums"]["fuzzy_precision"]
        }
        Returns: Json
      }
      get_tree_graph: { Args: { p_tree_id: string }; Returns: Json }
      hide_person_from_map: {
        Args: { p_person_id: string }
        Returns: undefined
      }
      is_confirmed_adult: { Args: never; Returns: boolean }
      is_tree_admin: { Args: { p_tree_id: string }; Returns: boolean }
      is_tree_member: { Args: { p_tree_id: string }; Returns: boolean }
      leave_tree: { Args: { p_tree_id: string }; Returns: undefined }
      mark_person_deceased: {
        Args: {
          p_death_date?: string
          p_death_date_end?: string
          p_death_date_precision?: Database["public"]["Enums"]["fuzzy_precision"]
          p_person_id: string
        }
        Returns: undefined
      }
      relationship_person_ids: {
        Args: { p_row: Json; p_table: string }
        Returns: string[]
      }
      release_claims_in_tree: {
        Args: { p_tree_id: string; p_user_id: string }
        Returns: undefined
      }
      remove_member: { Args: { p_member_id: string }; Returns: undefined }
      review_change_request: {
        Args: { p_approve: boolean; p_request_id: string }
        Returns: undefined
      }
      review_claim: {
        Args: { p_approve: boolean; p_claim_id: string }
        Returns: undefined
      }
      set_member_role: {
        Args: {
          p_member_id: string
          p_role: Database["public"]["Enums"]["tree_role"]
        }
        Returns: undefined
      }
      shares_tree_with: { Args: { p_user_id: string }; Returns: boolean }
      transfer_tree_ownership: {
        Args: { p_new_owner_user_id: string; p_tree_id: string }
        Returns: undefined
      }
      tree_id_from_storage_path: { Args: { p_name: string }; Returns: string }
      tree_role_of: {
        Args: { p_tree_id: string }
        Returns: Database["public"]["Enums"]["tree_role"]
      }
      undo_relationship_change: {
        Args: { p_change_id: string }
        Returns: string
      }
    }
    Enums: {
      feed_event_kind:
        | "person_added"
        | "person_claimed"
        | "person_marked_deceased"
        | "memory_added"
        | "member_joined"
      fuzzy_precision:
        | "exact"
        | "month"
        | "year"
        | "decade"
        | "about"
        | "before"
        | "after"
        | "between"
      memory_kind: "story" | "photo" | "video" | "audio"
      name_kind: "nickname" | "variant" | "married" | "other"
      notification_kind: "relationship_changed" | "change_request_received"
      parent_child_kind:
        | "biological"
        | "adoptive"
        | "step"
        | "foster"
        | "guardian"
      person_gender: "female" | "male" | "other"
      person_place_kind:
        | "birth"
        | "death"
        | "burial"
        | "residence"
        | "home_city"
      place_type:
        | "city"
        | "town"
        | "village"
        | "region"
        | "country"
        | "cemetery"
        | "place_of_worship"
      reaction_kind: "heart" | "hug" | "smile" | "candle"
      request_status: "pending" | "approved" | "rejected" | "withdrawn"
      tree_role: "owner" | "admin" | "member" | "viewer"
      union_kind: "marriage" | "civil_partnership" | "partnership"
      union_status:
        | "current"
        | "divorced"
        | "widowed"
        | "separated"
        | "annulled"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      feed_event_kind: [
        "person_added",
        "person_claimed",
        "person_marked_deceased",
        "memory_added",
        "member_joined",
      ],
      fuzzy_precision: [
        "exact",
        "month",
        "year",
        "decade",
        "about",
        "before",
        "after",
        "between",
      ],
      memory_kind: ["story", "photo", "video", "audio"],
      name_kind: ["nickname", "variant", "married", "other"],
      notification_kind: ["relationship_changed", "change_request_received"],
      parent_child_kind: [
        "biological",
        "adoptive",
        "step",
        "foster",
        "guardian",
      ],
      person_gender: ["female", "male", "other"],
      person_place_kind: ["birth", "death", "burial", "residence", "home_city"],
      place_type: [
        "city",
        "town",
        "village",
        "region",
        "country",
        "cemetery",
        "place_of_worship",
      ],
      reaction_kind: ["heart", "hug", "smile", "candle"],
      request_status: ["pending", "approved", "rejected", "withdrawn"],
      tree_role: ["owner", "admin", "member", "viewer"],
      union_kind: ["marriage", "civil_partnership", "partnership"],
      union_status: ["current", "divorced", "widowed", "separated", "annulled"],
    },
  },
} as const
