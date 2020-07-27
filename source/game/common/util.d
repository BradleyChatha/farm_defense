module game.common.util;

/// Used to visually identify `ref` params.
ref auto Ref(T)(ref scope return T v) { return v; }