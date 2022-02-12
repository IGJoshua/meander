use std::cmp::Ordering;

#[derive(PartialEq, Debug, Clone)]
pub enum Atom {
    SimpleSymbol(String),
    QualifiedSymbol(String, String),
    SimpleKeyword(String),
    QualifiedKeyword(String, String),
    Tuple(Vec<Atom>),
    Buffer(Vec<u8>),
    Integer(i64),
    Real(f64),
}

impl PartialOrd for Atom {
    fn partial_cmp(&self, other: &Atom) -> Option<Ordering> {
        match self {
            Self::SimpleSymbol(name) => {
                if let Self::SimpleSymbol(other) = other {
                    name.partial_cmp(other)
                } else {
                    None
                }
            }
            Self::QualifiedSymbol(namespace, name) => {
                if let Self::QualifiedSymbol(other_ns, other_name) = other {
                    let ns_ordering = namespace.partial_cmp(other_ns)?;
                    if let Ordering::Equal = ns_ordering {
                        name.partial_cmp(other_name)
                    } else {
                        Some(ns_ordering)
                    }
                } else {
                    None
                }
            }
            Self::SimpleKeyword(name) => {
                if let Self::SimpleKeyword(other) = other {
                    name.partial_cmp(other)
                } else {
                    None
                }
            }
            Self::QualifiedKeyword(namespace, name) => {
                if let Self::QualifiedKeyword(other_ns, other_name) = other {
                    let ns_ordering = namespace.partial_cmp(other_ns)?;
                    if let Ordering::Equal = ns_ordering {
                        name.partial_cmp(other_name)
                    } else {
                        Some(ns_ordering)
                    }
                } else {
                    None
                }
            }
            Self::Tuple(elts) => {
                if let Self::Tuple(other) = other {
                    elts.partial_cmp(other)
                } else {
                    None
                }
            }
            Self::Buffer(buf) => {
                if let Self::Buffer(other) = other {
                    buf.partial_cmp(other)
                } else {
                    None
                }
            }
            Self::Integer(i) => {
                if let Self::Integer(other) = other {
                    i.partial_cmp(other)
                } else {
                    None
                }
            }
            Self::Real(r) => {
                if let Self::Real(other) = other {
                    r.partial_cmp(other)
                } else {
                    None
                }
            }
        }
    }
}

impl Atom {
    pub fn to_string(&self) -> Option<String> {
        match self {
            Atom::Buffer(buf) => match String::from_utf8(buf.to_vec()) {
                Ok(buf) => Some(buf),
                Err(_) => None,
            },
            _ => None,
        }
    }
}
