import '../../../../models/artist.dart';

/// Strongly typed alias for the artist profile data model.
typedef ArtistProfile = Artist;

/// Strongly typed alias for an individual flash artwork piece.
typedef FlashPiece = FlashArtwork;

/// Re-export models for modular feature consumption.
export '../../../../models/artist.dart'
    show Artist, FlashArtwork, FlashStatus, ArtistFunFact, StudioPolicy;
