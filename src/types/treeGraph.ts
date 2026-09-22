import type { Enums } from './database';

/**
 * The shape returned by the get_tree_graph(tree_id) database function
 * (supabase/migrations/20260923000900_get_tree_graph.sql). The generated types only know
 * it returns JSON, so this spells it out. Keep the two in sync.
 */

/** A fuzzy date as returned by the database: see the fuzzy date migration for the rules. */
export type FuzzyDate = {
  /** ISO date (YYYY-MM-DD): the date, or the start of a 'between' range. */
  date: string;
  precision: Enums<'fuzzy_precision'>;
  /** Only for 'between'. */
  end: string | null;
};

export type TreeGraphPerson = {
  id: string;
  given_names: string | null;
  family_name: string | null;
  birth_family_name: string | null;
  gender: Enums<'person_gender'> | null;
  is_living: boolean;
  birth: FuzzyDate | null;
  death: FuzzyDate | null;
  is_claimed: boolean;
  profile_media_id: string | null;
};

export type TreeGraphParentChild = {
  id: string;
  parent_id: string;
  child_id: string;
  kind: Enums<'parent_child_kind'>;
  start: FuzzyDate | null;
  end: FuzzyDate | null;
};

export type TreeGraphUnion = {
  id: string;
  person_a_id: string;
  person_b_id: string;
  kind: Enums<'union_kind'>;
  status: Enums<'union_status'>;
  start: FuzzyDate | null;
  end: FuzzyDate | null;
};

export type TreeGraph = {
  tree_id: string;
  persons: TreeGraphPerson[];
  parent_child: TreeGraphParentChild[];
  unions: TreeGraphUnion[];
};
